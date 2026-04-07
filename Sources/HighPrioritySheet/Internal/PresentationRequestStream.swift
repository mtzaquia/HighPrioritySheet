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

import Combine

struct PresentationRequest<Item: Presentable>: Equatable {
    let item: Item?
}

struct PresentationRequestState<Item: Presentable>: Equatable {
    var current: PresentationRequest<Item>?
    var pending: PresentationRequest<Item>?
}

@MainActor
final class PresentationRequestStream<Item: Presentable> {
    private let stateSubject = CurrentValueSubject<PresentationRequestState<Item>, Never>(
        PresentationRequestState()
    )

    var publisher: AnyPublisher<PresentationRequestState<Item>, Never> {
        stateSubject
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    func send(_ item: Item?) {
        let request = PresentationRequest(item: item)
        var state = stateSubject.value

        if state.current == nil {
            state.current = request
            update(state)
            return
        }

        if state.pending != nil {
            state.pending = request
            update(state)
            return
        }

        if shouldReplaceItems(lhs: state.current?.item, rhs: item) {
            state.current = request
        } else {
            state.pending = request
        }

        update(state)
    }

    func acknowledgeCurrent() {
        var state = stateSubject.value
        guard state.current != nil else { return }

        state.current = state.pending
        state.pending = nil
        update(state)
    }

    private func update(_ state: PresentationRequestState<Item>) {
        guard stateSubject.value != state else { return }
        stateSubject.send(state)
    }
}
