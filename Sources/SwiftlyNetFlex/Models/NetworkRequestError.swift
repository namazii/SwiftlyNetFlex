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

// MARK: - Main Error protocol

public protocol ErrorRequestor: Error {

    var title: String { get set }
    var message: String { get set }
    var code: Int? { get set }

}

// MARK: -

public struct ErrorRequestNetwork: ErrorRequestor {

    public var title: String
    public var message: String
    public var code: Int?

    public init(title: String, message: String, code: Int? = nil) {
        self.title = title
        self.message = message
        self.code = code
    }
}

public struct ErrorRequestLocal: ErrorRequestor {

    public var title: String
    public var message: String
    public var code: Int?
    public var type: ErrorRequestLocalType
    
    public init(
        title: String,
        message: String,
        code: Int? = nil,
        type: ErrorRequestLocalType
    ) {
        self.title = title
        self.message = message
        self.code = code
        self.type = type
    }

    public enum ErrorRequestLocalType: String, Sendable {
        case timeout = "timeout"
        case nonconnection = "nonconnection"
        case errorParser = "errorParser"
        case badRequest = "badRequest"
        case any = "any"
    }

}
