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

public typealias NetworkRouterCompletion = (_ data: Data?, _ response: URLResponse?, _ error: Error?) -> Void

// MARK: - NetworkRouter
public protocol NetworkRouterProtocol: AnyObject {
    func request<T: Codable>(_ dataType: T.Type, _ route: EndPointType) async throws -> T
    func request<T: Codable>(dataType: T.Type, _ route: EndPointType) async throws -> T
    func request<T: Codable>(_ route: EndPointType, result: @escaping ResultRequest<T>)
    func request<T: Codable>(_ route: EndPointType, resultHandler: @escaping ResultRequest<T>)
    func request(_ route: EndPointType, completion: @escaping NetworkRouterCompletion)
    func cancel()
    func isRequesting() -> Bool
}

public final class NetworkRouter<Config: TokenRefreshConfiguration>: NSObject, NetworkRouterProtocol where Config.ResponseType: Codable {

    // MARK: Dependencies
    private let session: URLSession
    private let parserNetworkData: ParserNetworkDataProtocol
    private let queue = DispatchQueue(label: "com.network.queue", attributes: .concurrent)
    
    private var tasks = AtomicArray<URLSessionTask>()
    
    private let tokenAuthorizator: TokenAuthorizator<Config>
    private let refreshTokenConfigurator: Config

    // MARK: Initialization
    public init(
        session: URLSession = .shared,
        parserNetworkData: ParserNetworkDataProtocol = ParserNetworkData(),
        refreshTokenConfigurator: Config
    ) {
        self.session = session
        self.parserNetworkData = parserNetworkData
        self.refreshTokenConfigurator = refreshTokenConfigurator
        self.tokenAuthorizator = TokenAuthorizator(configurator: refreshTokenConfigurator)
    }

    // MARK: Modern Concurrency Wrapping
    public func request<T: Codable&Sendable>(_ dataType: T.Type, _ route: EndPointType) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            request(route, result: { (result: ResultRequestCase<T>) in
                switch result {
                case .success(let data):
                    continuation.resume(returning: data)
                case .errorNetwork(let error):
                    continuation.resume(throwing: error)
                case .errorLocal(let error):
                    continuation.resume(throwing: error)
                }
            })
        }
    }
    
    // MARK: Request without data
    public func request<T: Codable>(_ route: EndPointType, result: @escaping ResultRequest<T>) {
        request(route) { [weak self] data, response, error in
            guard let self = self else { return }

            self.parseRequestsResponse(data, response, error, resultHandler: result)
        }
    }

    // MARK: Request with data
    public func request<T: Codable>(_ route: EndPointType, resultHandler: @escaping ResultRequest<T>) {
        request(route) { [weak self] data, response, error  in
            guard let self = self else { return }
            
            self.parseStructRequestsResponse(data, response, error, resultHandler: resultHandler)
        }
    }
    
    public func request<T: Codable&Sendable>(dataType: T.Type, _ route: EndPointType) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            request(route, resultHandler: { (result: ResultRequestCase<T>) in
                switch result {
                case .success(let data):
                    continuation.resume(returning: data)
                case .errorNetwork(let error):
                    continuation.resume(throwing: error)
                case .errorLocal(let error):
                    continuation.resume(throwing: error)
                }
            })
        }
    }
    
    public func request(_ route: EndPointType, completion: @escaping NetworkRouterCompletion) {
        
        var task: URLSessionTask?
        
        do {
            let request = try buildRequest(from: route)

            task?.taskDescription = route.path

            task = session.dataTask(with: request) { [weak self] data, response, error in
                guard let self = self, let task = task, (error as NSError?)?.code != -999 else {
                    Log.error("Router: Task completion result invoke faild \nMaybe self or task is nil")
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
                    
                    self.queue.async { [weak task] in
                        self.tokenAuthorizator.updateTokens(router: self, with: route, completion: completion)
                        guard let task = task else { return }
                        self.tasks.cancelAll(where: { $0 == task })
                        self.tasks.remove(task)
                    }
                    return
                }

                self.tasks.remove(task)
                completion(data, response, error)
            }

            if let task = task {
                tasks.append(task)
                task.resume()
            }
        } catch {
            completion(nil, nil, error)
        }
    }

    public func cancel() {
        tasks.cancelAll()
        tasks.removeAll()
    }
    
    public func isRequesting() -> Bool {
        tasks.isNotEmpty
    }

    // MARK: - Request building
    private func buildRequest(from route: EndPointType) throws -> URLRequest {
        var request = URLRequest(
            url: route.baseURL.appendingPathComponent(route.path),
            cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
            timeoutInterval: 20
        )
        self.session.configuration.timeoutIntervalForRequest = 20
        self.session.configuration.timeoutIntervalForResource = 20

        request.httpMethod = route.httpMethod.rawValue

        let cookies = route.baseURL.readCookie()
        request.allHTTPHeaderFields = HTTPCookie.requestHeaderFields(with: cookies)

        do {
            switch route.task {
            case .request:
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            case .requestParameters(
                let bodyParameters,
                let bodyEncoding,
                let urlParameters
            ):
                try configureParameters(
                    bodyParameters: bodyParameters,
                    bodyEncoding: bodyEncoding,
                    urlParameters: urlParameters,
                    request: &request
                )
            case .requestParametersAndHeaders(
                let bodyParameters,
                let bodyEncoding,
                let urlParameters,
                let additionalHeaders
            ):
                addAdditionalHeaders(additionalHeaders, request: &request)
                try configureParameters(
                    bodyParameters: bodyParameters,
                    bodyEncoding: bodyEncoding,
                    urlParameters: urlParameters,
                    request: &request
                )
            }
            return request
        } catch {
            throw error
        }
    }

    private func configureParameters(
        bodyParameters: Parameters?,
        bodyEncoding: ParameterEncoding,
        urlParameters: Parameters?,
        request: inout URLRequest
    ) throws {
        do {
            try bodyEncoding.encode(
                urlRequest: &request,
                bodyParameters: bodyParameters,
                urlParameters: urlParameters
            )
        } catch {
            throw error
        }
    }

    private func addAdditionalHeaders(_ additionalHeaders: HTTPHeaders?, request: inout URLRequest) {
        guard let headers = additionalHeaders else {
            return
        }
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
    }

    // MARK: - Response parsing
    private func parseRequestsResponse<T: Codable>(
        _ data: Data?,
        _ response: URLResponse?,
        _ error: Error?,
        resultHandler: @escaping ResultRequest<T>
    ) {
        let completionRequest = CompletionRequest(data: data, response: response, error: error)
        
        let dataRequest = ParserNetworkResponseData(
            decodableStruct: NetworkResponseDefault<T>.self,
            completionRequest: completionRequest,
            resultHandler: resultHandler
        )
        self.parserNetworkData.parseRequestNetworkResponse(data: dataRequest)
    }
    
    
    private func parseStructRequestsResponse<T: Codable>(_ data: Data?, _ response: URLResponse?, _ error: Error?, resultHandler: @escaping ResultRequest<T>) {
        let completionRequest = CompletionRequest(data: data, response: response, error: error)
        
        let dataRequest = ParserCodableData(
            decodableStruct: T.self,
            completionRequest: completionRequest,
            resultHandler: resultHandler
        )
        self.parserNetworkData.parseStruct(data: dataRequest)
    }
    
}

// MARK: - URL
extension URL {
    
    func readCookie() -> [HTTPCookie] {
        let cookieStorage = HTTPCookieStorage.shared
        let cookies = cookieStorage.cookies(for: self) ?? []
        return cookies
    }
    
}
