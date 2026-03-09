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

public protocol TokenModelProtocol: Codable {
    var accessToken: String { get set }
    var refreshToken: String { get set }
}

public protocol TokenRefreshConfiguration {
    associatedtype ResponseType: TokenModelProtocol

    /// Получить refresh token
    func getRefreshToken() -> String?
    
    /// Сформировать запрос для обновления токена
    func makeRefreshTokenEndpoint(refreshToken: String) -> EndPointType
    
    /// Сохранить новые токены
    func saveTokens(_ token: ResponseType)
    
    /// Обработчик ошибки (например, разлогинивание)
    var onTokenRefreshFailed: (() -> Void)? { get }
}

final class TokenAuthorizator<ConfigurationType: TokenRefreshConfiguration>: @unchecked Sendable {
    
    private var requests = SafeArray<TokenAuthorizatorData>()
    private let queue = DispatchQueue(label: "com.example.TokenAuthorizator.queue", attributes: .concurrent)
    private let configuration: ConfigurationType
    
    init(configurator: ConfigurationType) {
        self.configuration = configurator
    }

    // MARK: - Public
    public func updateTokens(
        router: NetworkRouterProtocol,
        with route: EndPointType,
        isLog: Bool = true,
        completion: @escaping NetworkRouterCompletion
    ) {
        queue.async(flags: .barrier) {
            
            guard self.requests.arrayValues.isEmpty else {
                let data = TokenAuthorizatorData(router: router, route: route, isLog: isLog, completion: completion)
                self.requests.append(data)
                let values = self.requests.arrayValues.compactMap({ $0.route.path }).joined(separator: ", ")
                return
            }
            
            let data = TokenAuthorizatorData(router: router, route: route, isLog: isLog, completion: completion)
            self.requests.append(data)
            let values = self.requests.arrayValues.compactMap({ $0.route.path }).joined(separator: ", ")
            
            self.refreshToken(router: router, using: self.configuration) { [weak self] result in
                switch result {
                case .success(let data):
                    self?.configuration.saveTokens(data)
                    self?.retryQueuedRequests(token: data)
                    
                case .errorLocal(let error):
                    self?.configuration.onTokenRefreshFailed?()
                    self?.requests.removeAll()
                    
                case .errorNetwork(let error):
                    self?.configuration.onTokenRefreshFailed?()
                    self?.requests.removeAll()
                }
            }
        }
    }
    
    // MARK: - Private
    private func refreshToken(router: NetworkRouterProtocol, using config: ConfigurationType, completion: @escaping ResultRequest<ConfigurationType.ResponseType>) {
        guard let refreshToken = config.getRefreshToken() else {
            config.onTokenRefreshFailed?()
            self.requests.removeAll()
            return
        }
        
        let endpoint = config.makeRefreshTokenEndpoint(refreshToken: refreshToken)
        router.request(endpoint, result: completion)
    }
    
    private func retryQueuedRequests(token: ConfigurationType.ResponseType) {
        let requests = self.requests.arrayValues
        self.requests.removeAll()
        
        requests.forEach { data in
            let task = TaskBuilder()
                .clone(task: data.route.task)
                .updateAuthorize(token: token.accessToken)
                .build()
            
            let endPoint = EndPointBuilder(
                baseUrl:  data.route.baseURL.absoluteString,
                path: data.route.path,
                httpMethod: data.route.httpMethod,
                task: task
            ).build()
            
            data.router.request(endPoint, completion: data.completion)
        }
    }
    
}

struct TokenAuthorizatorData {
    let router: NetworkRouterProtocol
    let route: EndPointType
    let isLog: Bool
    let completion: NetworkRouterCompletion
}
