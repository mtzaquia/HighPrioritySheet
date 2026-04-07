//
//  HighPrioritySheet.swift
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
import UIKit

/// A value that can be presented by ``SwiftUICore/View/highPrioritySheet(item:content:)``.
///
/// The value identity is used to determine whether a change should replace the
/// current sheet content or dismiss and present a new sheet.
public typealias Presentable = Identifiable & Hashable

public extension View {
    /// Presents a sheet above the current presentation stack.
    ///
    /// This behaves similarly to SwiftUI's boolean-based sheet presentation,
    /// but is coordinated through UIKit so it can be presented from the
    /// current top-most controller.
    ///
    /// - Parameters:
    ///   - isPresented: The source of truth for presentation. `true` presents
    ///     the sheet. Setting it back to `false` dismisses it.
    ///   - content: A closure returning the content of the presented sheet.
    ///
    /// - Returns: A view that presents the provided content as a
    ///   high-priority sheet.
    func highPrioritySheet<Sheet: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Sheet
    ) -> some View {
        modifier(
            HighPrioritySheetModifier(
                item: isPresented.isPresent(),
                content: { _ in content() }
            )
        )
    }

    /// Presents a sheet above the current presentation stack.
    ///
    /// This behaves similarly to SwiftUI's item-based sheet presentation, but
    /// is coordinated through UIKit so it can be presented from the current
    /// top-most controller.
    ///
    /// If the bound item changes while a sheet is already presented:
    /// - The current content is replaced when the new item has the same `id`.
    /// - The current sheet is dismissed before presenting the next one when the
    ///   new item has a different `id`.
    ///
    /// - Parameters:
    ///   - item: The source of truth for presentation. A non-`nil` value
    ///     presents a sheet. Setting it back to `nil` dismisses it.
    ///   - content: A closure returning the content of the presented sheet for
    ///     the current item.
    ///
    /// - Returns: A view that presents the provided item as a high-priority
    ///   sheet.
    func highPrioritySheet<Item: Presentable, Sheet: View>(
        item: Binding<Item?>,
        content: @escaping (Item) -> Sheet
    ) -> some View {
        modifier(HighPrioritySheetModifier(item: item, content: content))
    }
}

private struct HighPrioritySheetModifier<Item: Presentable, Sheet: View>: ViewModifier {
    @Binding var item: Item?
    @ViewBuilder let content: (Item) -> Sheet

    @State private var requestStream = PresentationRequestStream<Item>()

    func body(content: Content) -> some View {
        content
            .background {
                ControllerBridge(
                    item: $item,
                    requestStream: requestStream,
                    content: self.content
                )
                .frame(width: .zero, height: .zero)
            }
            .task(id: item?.id) {
                requestStream.send(item)
            }
    }
}
