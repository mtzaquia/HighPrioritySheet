//
//  PresentationRequestStream.swift
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

struct PresentationRequest<Item: Presentable>: Equatable {
    let item: Item?
}

final class PresentationRequestStream<Item: Presentable> {
    let stream: AsyncStream<PresentationRequest<Item>>

    private var continuation: AsyncStream<PresentationRequest<Item>>.Continuation
    private var current: PresentationRequest<Item>?
    private var pending: PresentationRequest<Item>?

    init() {
        (self.stream, self.continuation) = AsyncStream.makeStream(of: PresentationRequest<Item>.self)
    }

    deinit {
        continuation.finish()
    }

    func send(_ item: Item?) {
        let request = PresentationRequest(item: item)

        if current == request || pending == request {
            return
        }

        if current == nil {
            current = request
            emitCurrentIfNeeded()
            return
        }

        pending = request
    }

    func acknowledgeCurrent() {
        current = pending
        pending = nil
        emitCurrentIfNeeded()
    }

    private func emitCurrentIfNeeded() {
        guard let request = current else { return }
        _ = continuation.yield(request)
    }
}
