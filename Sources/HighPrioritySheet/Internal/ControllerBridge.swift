//
//  ControllerBridge.swift
//
//  Copyright (c) 2026 @mtzaquia
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

import SwiftUI

struct ControllerBridge<Item: Presentable, Sheet: View>: UIViewControllerRepresentable {
    @Binding var item: Item?
    let onDismiss: (() -> Void)?
    @ViewBuilder let content: (Item) -> Sheet

    let requestStream: PresentationRequestStream<Item>

    func makeCoordinator() -> Coordinator {
        Coordinator(
            item: $item,
            onDismiss: onDismiss,
            content: content,
            requestStream: requestStream
        )
    }

    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        controller.view.backgroundColor = .clear
        controller.view.isHidden = true
        context.coordinator.attach(to: controller)
        return controller
    }

    func updateUIViewController(
        _ uiViewController: UIViewController,
        context: Context
    ) {
        context.coordinator.attach(to: uiViewController)
        context.coordinator.updateItemBinding($item)
        context.coordinator.updateOnDismiss(onDismiss)
        context.coordinator.updateContent(content, environment: context.environment)
    }
}

extension ControllerBridge {
    @MainActor
    final class Coordinator {
        private weak var anchorController: UIViewController?
        private let requestStream: PresentationRequestStream<Item>
        private var itemBinding: Binding<Item?>
        private var onDismiss: (() -> Void)?
        private var content: (Item) -> Sheet
        private var environment = EnvironmentValues()
        private var currentItem: Item?
        private var holderController: HostingControllerHolder<Item, Sheet>?
        private var requestTask: Task<Void, Error>?
        private var sheetDismissalContinuation: CheckedContinuation<Void, Never>?

        init(
            item: Binding<Item?>,
            onDismiss: (() -> Void)?,
            content: @escaping (Item) -> Sheet,
            requestStream: PresentationRequestStream<Item>
        ) {
            self.itemBinding = item
            self.onDismiss = onDismiss
            self.content = content
            self.requestStream = requestStream

            requestTask = Task { [weak self, requestStream] in
                for await request in requestStream.stream {
                    try Task.checkCancellation()

                    guard let self else { return }
                    await handle(request)
                    requestStream.acknowledgeCurrent()
                }
            }
        }

        func attach(to controller: UIViewController) {
            anchorController = controller
        }

        func updateItemBinding(_ item: Binding<Item?>) {
            itemBinding = item
        }

        func updateOnDismiss(_ onDismiss: (() -> Void)?) {
            self.onDismiss = onDismiss
        }

        func updateContent(_ content: @escaping (Item) -> Sheet, environment: EnvironmentValues) {
            self.content = content
            self.environment = environment
            holderController?.updateContent(content, environment: environment)
        }

        private func handle(_ request: PresentationRequest<Item>) async {
            switch (currentItem, request.item) {
            case (.none, .none):
                return

            case let (.none, item?):
                await present(item)

            case (.some, .none):
                await dismissCurrentPresentation(notifyOnDismiss: true)

            case let (currentItem?, requestedItem?):
                if shouldReplaceItems(lhs: currentItem, rhs: requestedItem) {
                    replaceCurrentPresentation(with: requestedItem)
                } else {
                    await dismissCurrentPresentation(notifyOnDismiss: false)
                    await present(requestedItem)
                }
            }
        }

        private func present(_ item: Item) async {
            guard let topController = await waitForPresentationController() else {
                return
            }

            await waitForUIKitTransitionIfNeeded(on: topController)

            let holder = HostingControllerHolder(
                item: item,
                environment: environment,
                content: content,
                onSheetDismiss: { [weak self] in
                    self?.sheetDidDismiss()
                }
            )

            currentItem = item
            holderController = holder

            await withCheckedContinuation { continuation in
                topController.present(holder, animated: false) {
                    continuation.resume()
                }
            }
        }

        private func dismissCurrentPresentation(notifyOnDismiss: Bool) async {
            guard let holderController else {
                currentItem = nil
                if notifyOnDismiss {
                    onDismiss?()
                }
                return
            }

            await waitForUIKitTransitionIfNeeded(on: holderController)
            await dismissPresentedSheetIfNeeded(from: holderController)

            if let currentItem,
               itemBinding.wrappedValue?.id == currentItem.id {
                itemBinding.wrappedValue = nil
            }

            await withCheckedContinuation { continuation in
                holderController.dismiss(animated: false) {
                    continuation.resume()
                }
            }

            currentItem = nil
            self.holderController = nil

            if notifyOnDismiss {
                onDismiss?()
            }
        }

        private func replaceCurrentPresentation(with item: Item) {
            currentItem = item
            holderController?.replace(with: item)
        }

        private func waitForPresentationController() async -> UIViewController? {
            while Task.isCancelled == false {
                if let anchorController {
                    if currentItem != nil || anchorController.viewIfLoaded?.window != nil {
                        return anchorController.topMostViewController()
                    }
                }

                await Task.yield()
            }

            return nil
        }

        private func waitForUIKitTransitionIfNeeded(on controller: UIViewController) async {
            guard let transitionCoordinator = controller.transitionCoordinator else { return }

            await withCheckedContinuation { continuation in
                transitionCoordinator.animate(alongsideTransition: nil) { _ in
                    continuation.resume()
                }
            }
        }

        private func dismissPresentedSheetIfNeeded(from holderController: HostingControllerHolder<Item, Sheet>) async {
            await withCheckedContinuation { continuation in
                sheetDismissalContinuation = continuation

                if holderController.dismissSheet() == false {
                    sheetDismissalContinuation = nil
                    continuation.resume()
                }
            }
        }

        private func sheetDidDismiss() {
            sheetDismissalContinuation?.resume()
            sheetDismissalContinuation = nil

            if let currentItem,
               itemBinding.wrappedValue?.id == currentItem.id {
                itemBinding.wrappedValue = nil
            }
        }
    }
}
