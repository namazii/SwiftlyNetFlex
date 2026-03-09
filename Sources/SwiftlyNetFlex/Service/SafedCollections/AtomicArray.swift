//
// MIT License
//
// Copyright (c) 2026 Nazar Tkacenko
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//

import Foundation

// MARK: -

protocol Atomicable {

    func lock()
    func unlock()

}

// MARK: -

final class SpinLock: Atomicable {

    private var unfairLock = os_unfair_lock_s()

    func lock() {
        os_unfair_lock_lock(&unfairLock)
    }

    func unlock() {
        os_unfair_lock_unlock(&unfairLock)
    }

}

// MARK: -

final class AtomicArray<Element: URLSessionTask> {

    private let locker: Atomicable
    private var array = [Element]()

    init(locker: Atomicable = SpinLock()) {
        self.locker = locker
    }

}

// MARK: - Properties

extension AtomicArray {

    var count: Int {
        locker.lock()
        defer {
            locker.unlock()
        }

        return array.count
    }

    var isEmpty: Bool {
        locker.lock()
        defer {
            locker.unlock()
        }

        return array.isEmpty
    }

    var isNotEmpty: Bool {
        locker.lock()
        defer {
            locker.unlock()
        }
        return !array.isEmpty
    }

    var capacity: Int {
        locker.lock()
        defer {
            locker.unlock()
        }
        return array.capacity
    }

    var description: String {
        locker.lock()
        defer {
            locker.unlock()
        }
        return array.description
    }

}

// MARK: - Immutabale

extension AtomicArray {

    func reserveCapacity(minimumCapacity: Int) {
        locker.lock()
        defer {
            locker.unlock()
        }
        array.reserveCapacity(minimumCapacity)
    }

    func reserveCapacity(n: Int) {
        locker.lock()
        defer {
            locker.unlock()
        }
        array.reserveCapacity(n)
    }

}

// MARK: - Mutable

extension AtomicArray {

    func append(_ element: Element) {
        locker.lock()
        defer {
            locker.unlock()
        }

        array.append(element)
    }

    func append(_ elements: [Element]) {
        locker.lock()
        defer {
            locker.unlock()
        }

        array.append(contentsOf: elements)
    }

    func remove(at index: Int) {
        locker.lock()
        defer {
            locker.unlock()
        }

        array.remove(at: index)
    }

    func remove(_ element: Element) {
        locker.lock()
        defer {
            locker.unlock()
        }

        array.removeAll(where: { $0 == element })
    }

    func removeAll(keepingCapacity isKeeping: Bool) {
        locker.lock()
        defer {
            locker.unlock()
        }

        array.removeAll(keepingCapacity: isKeeping)
    }

    func removeAll() {
        locker.lock()
        defer {
            locker.unlock()
        }

        array.removeAll()
    }

}

// MARK: -

extension AtomicArray {

    func compactMap<ElementOfResult>(_ transform: (Element) -> ElementOfResult?) -> [ElementOfResult] {

        locker.lock()
        defer {
            locker.unlock()
        }

        return array.compactMap(transform)
    }

    func getArray() -> [Element] {
        locker.lock()
        defer {
            locker.unlock()
        }

        return array
    }

}

// MARK: -

extension AtomicArray where Element: Equatable {

    func containts(_ element: Element) -> Bool {
        locker.lock()
        defer {
            locker.unlock()
        }

        return array.contains(element)
    }

}

// MARK: -

extension AtomicArray {

    func cancelAll() {
        locker.lock()
        defer {
            locker.unlock()
        }

        array.forEach { $0.cancel() }
    }

    func cancelAll(where find: (Element) -> (Bool)) {
        locker.lock()
        defer {
            locker.unlock()
        }

        array.filter(find).forEach { $0.cancel() }
        array.removeAll(where: find)
    }

}
