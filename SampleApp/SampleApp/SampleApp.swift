//
//  SampleApp.swift
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

import HighPrioritySheet
import SwiftUI

@main
struct SampleAppApp: App {
    var body: some Scene {
        WindowGroup {
            HighPrioritySheetDemoView()
        }
    }
}

// MARK: - Demo

struct HighPrioritySheetDemoView: View {
    @State private var sheet: DemoSheetItem?
    @State private var highPrioritySheet: DemoSheetItem?

    init() {}

    var body: some View {
        VStack {
            LabeledContent(
                "Sheet state",
                value: sheet?.id.uuidString ?? "nil"
            )

            LabeledContent(
                "High priority sheet",
                value: highPrioritySheet?.id.uuidString ?? "nil"
            )

            Button("Present sheet") { sheet = DemoSheetItem() }
            Button("Present high priority sheet") { highPrioritySheet = DemoSheetItem() }
        }
        .padding()
        .sheet(
            item: $sheet,
            content: {
                DemoSheetView(
                    sheet: $0,
                    sheetBinding: $sheet,
                    highPrioritySheet: $highPrioritySheet
                )
            }
        )
        .highPrioritySheet(
            item: $highPrioritySheet,
            content: {
                DemoHighPrioritySheetView(
                    sheet: $0,
                    sheetBinding: $sheet,
                    highPrioritySheet: $highPrioritySheet
                )
            }
        )
    }
}

private struct DemoSheetItem: Presentable {
    let id = UUID()
}

private struct DemoSheetView: View {
    let sheet: DemoSheetItem
    @Binding var sheetBinding: DemoSheetItem?
    @Binding var highPrioritySheet: DemoSheetItem?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack {
            Text(sheet.id.uuidString)
            Button("Present high priority sheet") { highPrioritySheet = DemoSheetItem() }
            Button("Dismiss via binding") { sheetBinding = nil }
            Button("Dismiss via environment") { dismiss() }
        }
    }
}

private struct DemoHighPrioritySheetView: View {
    let sheet: DemoSheetItem
    @Binding var sheetBinding: DemoSheetItem?
    @Binding var highPrioritySheet: DemoSheetItem?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack {
            Text("High prio: \(sheet.id.uuidString)")
            Button("Replace high priority sheet") { highPrioritySheet = DemoSheetItem() }
            Button("Dismiss via binding") { highPrioritySheet = nil }
            Button("Dismiss via environment") { dismiss() }

            Button("Dismiss sheet", role: .destructive) { sheetBinding = nil }
        }
    }
}
