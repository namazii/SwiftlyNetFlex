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

public protocol NetworkResponse: Codable {

    associatedtype U: Codable
    var data: U { get }
    var error: Bool? { get }
    var code: Int? { get }
    var message: String? { get }

}

// MARK: -

public struct NetworkResponseDefault<T: Codable>: NetworkResponse {

    public var data: T
    public var error: Bool?
    public var code: Int?
    public var message: String?

}

// MARK: -

public enum NetworkResponseResult<String> {

    case success
    case failure(String)

}

// MARK: -

public enum NetworkResponseErrorString: String {

    case success
    case authenticationError
    case badRequest
    case outdated
    case failed
    case noData
    case unableToDecode
    case userNotFound

    public init?(rawValue: String) {
        return nil
    }

    public var rawValue: String {
        return switch self {
        case .success: ""
        case .authenticationError: "Strings.Localizable.Error.Network.authentication"
        case .badRequest: "Strings.Localizable.Error.Network.badRequest"
        case .outdated: "Strings.Localizable.Error.Network.outdated"
        case .failed: "Strings.Localizable.Error.Network.failed"
        case .noData: "Strings.Localizable.Error.Network.noData"
        case .unableToDecode: "Strings.Localizable.Error.Network.unableToDecode"
        case .userNotFound: "Strings.Localizable.Error.Network.userNotFound"
        }
    }

}
