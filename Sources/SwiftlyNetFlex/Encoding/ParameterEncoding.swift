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

public typealias Parameters = [String: Any]

// MARK: -

public protocol ParameterEncoder {

    func encode(urlRequest: inout URLRequest, with parameters: Parameters) throws

}

// MARK: -

public enum ParameterEncoding {

    case urlEncoding
    case jsonEncoding
    case urlAndJsonEncoding

    func encode(
        urlRequest: inout URLRequest,
        bodyParameters: Parameters?,
        urlParameters: Parameters?
    ) throws {
        do {
            switch self {
            case .urlEncoding:
                guard let urlParameters = urlParameters else {
                    return
                }
                try URLParameterEncoder().encode(urlRequest: &urlRequest, with: urlParameters)
            case .jsonEncoding:
                guard let bodyParameters = bodyParameters else {
                    return
                }
                try JSONParameterEncoder().encode(urlRequest: &urlRequest, with: bodyParameters)
            case .urlAndJsonEncoding:
                guard
                    let bodyParameters = bodyParameters,
                      let urlParameters = urlParameters
                else {
                    return
                }
                try URLParameterEncoder().encode(urlRequest: &urlRequest, with: urlParameters)
                try JSONParameterEncoder().encode(urlRequest: &urlRequest, with: bodyParameters)
            }
        } catch {
            throw error
        }
    }

}

// MARK: -
enum EncodingError: String, Error {
    case failed = "Parameter encoding failed."
    case missingURL = "URL is nil."
}
