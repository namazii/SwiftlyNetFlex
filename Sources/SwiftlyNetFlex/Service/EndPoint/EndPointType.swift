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

public protocol EndPointType {
    var baseURL: URL { get }
    var path: String { get }
    var httpMethod: HTTPMethod { get }
    var task: HTTPTask { get }
}

public class EndPoint: EndPointType {
    
    public var baseURL: URL {
        guard let url = URL(string: environmentBaseURL) else { fatalError("baseURL could not be configured.")}
        return url
    }

    public let environmentBaseURL: String
    public let path: String
    public let httpMethod: HTTPMethod
    public let task: HTTPTask

    public init(baseUrl: String, path: String, httpMethod: HTTPMethod, task: HTTPTask) {
        self.environmentBaseURL = baseUrl
        self.path = path
        self.httpMethod = httpMethod
        self.task = task
    }

}

public class TaskBuilder {

    private var bodyParam: Parameters?
    private var urlParam: Parameters?
    private var headers: HTTPHeaders
    
    public init(headers: HTTPHeaders, bodyParam: Parameters? = nil, urlParam: Parameters? = nil) {
        self.headers = headers
        self.bodyParam = bodyParam
        self.urlParam = urlParam
    }
    
    public init() {
        self.headers = [:]
        self.bodyParam = nil
        self.urlParam = nil
    }
    
    public func build() -> HTTPTask {
        .requestParametersAndHeaders(
            bodyParameters: bodyParam,
            bodyEncoding: encodingByParam(),
            urlParameters: urlParam,
            additionHeaders: headers
        )
    }
    
    private func encodingByParam() -> ParameterEncoding {
        var encoding: ParameterEncoding = .urlEncoding
        if (urlParam != nil) && (bodyParam != nil) {
            encoding = .urlAndJsonEncoding
        } else {
            if bodyParam != nil {
                encoding = .jsonEncoding
            } else {
                encoding = .urlEncoding
            }
        }
        return encoding
    }
    
    public func addHeaders(headers: HTTPHeaders) -> TaskBuilder {
        self.headers = self.headers.merging(headers, uniquingKeysWith: { (_, new) in new})
        return self
    }
    
    public func updateAuthorize(token: String) -> TaskBuilder {
        self.headers.removeValue(forKey: "Authorization")
        return addHeaders(headers: ["Authorization": token])
    }
    
    public func clone(task: HTTPTask) -> TaskBuilder {
        switch task {
        case .request:
            break
        case .requestParameters(let bodyParameters, _, let urlParameters):
            self.bodyParam = bodyParameters
            self.urlParam = urlParameters
        case .requestParametersAndHeaders(let bodyParameters, _, let urlParameters, let additionHeaders):
            self.bodyParam = bodyParameters
            self.urlParam = urlParameters
            self.headers = additionHeaders ?? [:]
        }
        return self
    }

}

public final class EndPointBuilder {

    private var baseUrl: String
    private var path: String
    private var httpMethod: HTTPMethod
    private var task: HTTPTask
    
    public init(baseUrl: String, path: String, httpMethod: HTTPMethod = .get, headers: HTTPHeaders, bodyParam: Parameters? = nil, urlParam: Parameters? = nil) {
        self.baseUrl = baseUrl
        self.path = path
        self.httpMethod = httpMethod
        self.task = TaskBuilder(headers: headers, bodyParam: bodyParam, urlParam: urlParam).build()
    }
    
    public init(baseUrl: String, path: String, httpMethod: HTTPMethod, task: HTTPTask) {
        self.baseUrl = baseUrl
        self.path = path
        self.httpMethod = httpMethod
        self.task = task
    }

    public func build() -> EndPoint {
        EndPoint(baseUrl: baseUrl, path: path, httpMethod: httpMethod, task: task)
    }

}
