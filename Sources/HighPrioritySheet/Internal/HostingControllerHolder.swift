//
//  HostingControllerHolder.swift
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

@Observable
private final class SheetPresentationStore<Item: Presentable> {
    var environmentValues = EnvironmentValues()
    var item: Item?
}

private struct SheetPresentationView<Item: Presentable, Sheet: View>: View {
    @Bindable var store: SheetPresentationStore<Item>
    @ViewBuilder let content: (Item) -> Sheet
    let onDismiss: () -> Void

    var body: some View {
        Color.clear
            .sheet(
                item: $store.item,
                onDismiss: onDismiss,
                content: content
            )
            .environment(\.self, store.environmentValues)
    }
}

final class HostingControllerHolder<Item: Presentable, Sheet: View>: UIViewController {
    private let store = SheetPresentationStore<Item>()
    private let onSheetDismiss: () -> Void
    private var content: (Item) -> Sheet
    private var hostingController: UIHostingController<SheetPresentationView<Item, Sheet>>?
    private var pendingItem: Item
    private var hasPresentedInitialSheet = false

    init(
        item: Item,
        environment: EnvironmentValues,
        content: @escaping (Item) -> Sheet,
        onSheetDismiss: @escaping () -> Void
    ) {
        self.pendingItem = item
        self.content = content
        self.onSheetDismiss = onSheetDismiss
        super.init(nibName: nil, bundle: nil)
        store.environmentValues = environment
        modalPresentationStyle = .overFullScreen
        view.backgroundColor = .clear
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        let hostingController = UIHostingController(rootView: makeRootView())
        hostingController.view.backgroundColor = .clear
        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        hostingController.didMove(toParent: self)
        self.hostingController = hostingController
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        guard hasPresentedInitialSheet == false else { return }
        hasPresentedInitialSheet = true
        store.item = pendingItem
    }

    func updateContent(_ content: @escaping (Item) -> Sheet, environment: EnvironmentValues) {
        self.content = content
        self.store.environmentValues = environment
        hostingController?.rootView = makeRootView()
    }

    func replace(with item: Item) {
        pendingItem = item

        guard hasPresentedInitialSheet else { return }
        store.item = item
    }

    @discardableResult
    func dismissSheet() -> Bool {
        guard hasPresentedInitialSheet, store.item != nil else {
            return false
        }

        store.item = nil
        return true
    }

    private func makeRootView() -> SheetPresentationView<Item, Sheet> {
        SheetPresentationView(
            store: store,
            content: content,
            onDismiss: onSheetDismiss
        )
    }
}
