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

import Combine
import SwiftUI

struct ControllerBridge<Item: Presentable, Sheet: View>: UIViewControllerRepresentable {
    @Binding var item: Item?
    let requestStream: PresentationRequestStream<Item>
    @ViewBuilder let content: (Item) -> Sheet

    func makeCoordinator() -> Coordinator {
        Coordinator(
            requestStream: requestStream,
            item: $item,
            content: content
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
        context.coordinator.updateContent(content, environment: context.environment)
        context.coordinator.processCurrentRequest()
    }
}

private enum TransitionAction<Item: Presentable> {
    case present(Item)
    case dismiss
    case replace(Item)
    case none
}

extension ControllerBridge {
    @MainActor
    final class Coordinator {
        private weak var anchorController: UIViewController?
        private let requestStream: PresentationRequestStream<Item>
        private var itemBinding: Binding<Item?>
        private var content: (Item) -> Sheet
        private var environment = EnvironmentValues()
        private var requestState = PresentationRequestState<Item>()
        private var currentItem: Item?
        private var holderController: HostingControllerHolder<Item, Sheet>?
        private var waitingForUIKitTransition = false
        private var waitingForSwiftUIDismissal = false
        private var cancellable: AnyCancellable?

        init(
            requestStream: PresentationRequestStream<Item>,
            item: Binding<Item?>,
            content: @escaping (Item) -> Sheet
        ) {
            self.requestStream = requestStream
            self.itemBinding = item
            self.content = content
            cancellable = requestStream.publisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self] state in
                    guard let self else { return }
                    requestState = state
                    processCurrentRequest()
                }
        }

        func attach(to controller: UIViewController) {
            anchorController = controller
        }

        func updateItemBinding(_ item: Binding<Item?>) {
            itemBinding = item
        }

        func updateContent(_ content: @escaping (Item) -> Sheet, environment: EnvironmentValues) {
            self.content = content
            self.environment = environment
            holderController?.updateContent(content, environment: environment)
        }

        func processCurrentRequest() {
            guard !waitingForUIKitTransition, !waitingForSwiftUIDismissal else { return }
            guard requestState.current != nil else { return }

            let action = transitionAction(for: requestState.current?.item)
            if case .present = action {
                guard let anchorController else { return }
                guard currentItem != nil || anchorController.viewIfLoaded?.window != nil else { return }
            }

            process(action)
        }

        private func transitionAction(for requestedItem: Item?) -> TransitionAction<Item> {
            switch (currentItem, requestedItem) {
            case (.none, .none):
                return .none
                
            case let (.none, item?):
                return .present(item)

            case (.some, .none):
                return .dismiss

            case let (currentItem?, requestedItem?):
                if shouldReplaceItems(lhs: currentItem, rhs: requestedItem) {
                    return .replace(requestedItem)
                }

                return .dismiss
            }
        }

        private func process(_ action: TransitionAction<Item>) {
            switch action {
            case let .present(item):
                present(item)
            case .dismiss:
                dismissCurrentPresentation()
            case let .replace(item):
                replaceCurrentPresentation(with: item)
            case .none:
                requestStream.acknowledgeCurrent()
            }
        }

        private func present(_ item: Item) {
            guard let anchorController else {
                return
            }

            let topController = anchorController.topMostViewController()
            runAfterUIKitTransitionIfNeeded(on: topController) { [weak self, weak topController] in
                guard let self, let topController else { return }

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
                topController.present(holder, animated: false)
                requestStream.acknowledgeCurrent()
            }
        }

        private func dismissCurrentPresentation() {
            guard let holderController else {
                currentItem = nil
                processCurrentRequest()
                return
            }

            runAfterUIKitTransitionIfNeeded(on: holderController) { [weak self, weak holderController] in
                guard let self, let holderController else { return }

                waitingForSwiftUIDismissal = holderController.dismissSheet()
                if waitingForSwiftUIDismissal == false {
                    sheetDidDismiss()
                }
            }
        }

        private func replaceCurrentPresentation(with item: Item) {
            currentItem = item
            holderController?.replace(with: item)
            requestStream.acknowledgeCurrent()
        }

        private func sheetDidDismiss() {
            waitingForSwiftUIDismissal = false

            if let currentItem,
               itemBinding.wrappedValue?.id == currentItem.id {
                itemBinding.wrappedValue = nil
            }

            guard let holderController else {
                currentItem = nil
                processCurrentRequest()
                return
            }

            holderController.dismiss(animated: false) { [weak self] in
                guard let self else { return }
                self.currentItem = nil
                self.holderController = nil
                self.processCurrentRequest()
            }
        }

        private func runAfterUIKitTransitionIfNeeded(
            on controller: UIViewController,
            _ action: @escaping @MainActor () -> Void
        ) {
            guard let transitionCoordinator = controller.transitionCoordinator else {
                action()
                return
            }

            waitingForUIKitTransition = true
            transitionCoordinator.animate(alongsideTransition: nil) { [weak self] _ in
                guard let self else { return }
                waitingForUIKitTransition = false
                action()
            }
        }
    }
}
