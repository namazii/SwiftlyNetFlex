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
import Network

// MARK: -

private func handleNetworkResponse(_ response: HTTPURLResponse) -> NetworkResponseResult<String> {

    switch response.statusCode {
    case 200...299: return .success
    case 404: return .failure(NetworkResponseErrorString.userNotFound.rawValue)
    case 307: return .success
    case 401...500: return .failure(NetworkResponseErrorString.authenticationError.rawValue)
    case 501...599: return .failure(NetworkResponseErrorString.badRequest.rawValue)
    case 600: return .failure(NetworkResponseErrorString.outdated.rawValue)
    default: return .failure(NetworkResponseErrorString.failed.rawValue)
    }

}


// MARK: - response without data

public struct ParserNetworkResponseData<T: NetworkResponse> {

    public var decodableStruct: T.Type
    public var completionRequest: CompletionRequest
    public var resultHandler: ResultRequest<T.U>
    
    public init(decodableStruct: T.Type, completionRequest: CompletionRequest, resultHandler: @escaping ResultRequest<T.U>) {
        self.decodableStruct = decodableStruct
        self.completionRequest = completionRequest
        self.resultHandler = resultHandler
    }

}

// MARK: - response with data

public struct ParserCodableData<T> {

    var decodableStruct: T.Type
    var completionRequest: CompletionRequest
    var resultHandler: ResultRequest<T>
    
    public init(decodableStruct: T.Type, completionRequest: CompletionRequest, resultHandler: @escaping ResultRequest<T>) {
        self.decodableStruct = decodableStruct
        self.completionRequest = completionRequest
        self.resultHandler = resultHandler
    }

}

// MARK: -
public protocol ParserNetworkDataProtocol {
    func parseRequestNetworkResponse<T: NetworkResponse>(data: ParserNetworkResponseData<T>)
    func parseStruct<T: Codable>(data: ParserCodableData<T>)
}
 
public final class ParserNetworkData: ParserNetworkDataProtocol {
    
    public init() {}

    public func parseRequestNetworkResponse<T: NetworkResponse>(data: ParserNetworkResponseData<T>) {
        parse(
            decodableStruct: data.decodableStruct,
            completionRequest: data.completionRequest
        ) {
            $0.mapResult(data.resultHandler) {
                $0.data
            }
        }
    }

    public func parseStruct<T: Codable>(data: ParserCodableData<T>) {
        parse(
            decodableStruct: data.decodableStruct,
            completionRequest: data.completionRequest,
            resultHandler: data.resultHandler
        )
    }

}

// MARK: -

private extension ParserNetworkData {

    func getQueryStringParameter(url: String, param: String) -> String? {
        guard let url = URLComponents(string: url) else { return nil }
        return url.queryItems?.first(where: { $0.name == param })?.value
    }

}

// MARK: -

private extension ParserNetworkData {
    func parse<T: Codable>(
        decodableStruct: T.Type,
        completionRequest: CompletionRequest,
        resultHandler: @escaping ResultRequest<T>
    ) {
        let decodeStruct = decodableStruct
        let completionRequest = completionRequest
        let resultHandler = resultHandler
        let error = completionRequest.error
        let response = completionRequest.response
        let data = completionRequest.data

        let jsonDecoder = JSONDecoder()
        jsonDecoder.keyDecodingStrategy = .convertFromSnakeCase

        localError(decodableStruct: decodeStruct, completionRequest: completionRequest, resultHandler: resultHandler)
        
        if let response = response as? HTTPURLResponse {
            let result = handleNetworkResponse(response)
            Log.info("Code: \(response.statusCode) <-------------\n\n\(response.url?.absoluteString ?? "")\n")
            switch result {
            case .success:
                guard let responseData = data else {
                    let error = ErrorRequestLocal(
                        title: NetworkResponseErrorString.noData.rawValue,
                        message: error?.localizedDescription ?? "",
                        type: .any
                    )
                    Log.error("ParserNetworkData parse() error\(error.message)")
                    resultHandler(.errorLocal(error: error))
                    return
                }
                if !(response.url?.absoluteString.contains("getPVZ") ?? false) {
                    Log.info("\nRESPONSE: \(responseData.prettyPrintedJSONString ?? "")")
                }

                do {
                    let apiResponse = try jsonDecoder.decode(decodeStruct.self, from: responseData)
                    resultHandler(.success(apiResponse))
                } catch DecodingError.keyNotFound(let key, let context) {
                    Log.error("could not find key \(key) in JSON: \(context.debugDescription)")
                    parserError(data: data, error: error, result: resultHandler)
                } catch DecodingError.valueNotFound(let type, let context) {
                    Log.error("could not find type \(type) in JSON: \(context.debugDescription)")
                    parserError(data: data, error: error, result: resultHandler)
                } catch DecodingError.typeMismatch(let type, let context) {
                    Log.error("type mismatch for type \(type) in JSON: \(context.debugDescription)")
                    parserError(data: data, error: error, result: resultHandler)
                } catch DecodingError.dataCorrupted(let context) {
                    Log.error("data found to be corrupted in JSON: \(context.debugDescription)")
                    parserError(data: data, error: error, result: resultHandler)
                } catch let error as NSError {
                    Log.error("Error in read(from:ofType:) domain= \(error.domain), description= \(error.localizedDescription)")
                    parserError(data: data, error: error, result: resultHandler)
                } catch let error {
                    Log.error("Error in ParserNetworkData parse()")
                    parserError(data: data, error: error, result: resultHandler)
                }
            case .failure(let networkFailureError):
                var messageError: String?
                
                if let responseData = data,
                   let message = try? JSONDecoder().decode(FailureData.self, from: responseData).message {
                    messageError = message
                }
                
                let error = ErrorRequestNetwork(title: messageError ?? networkFailureError,
                                                message: error?.localizedDescription ?? networkFailureError,
                                                code: response.statusCode)
                Log.error("Code: \(String(error.code ?? 0)) - Message: \(error.title)")
                resultHandler(.errorNetwork(error: error))
            }
        }
    }

    func localError<T: Codable>(decodableStruct: T.Type,
                                completionRequest: CompletionRequest,
                                resultHandler: @escaping ResultRequest<T>) {
        
        if !NetworkMonitor.shared.isConnected {
            let error = ErrorRequestLocal(
                title: "Нет интернета",
                message: "Попробовать снова",
                type: .nonconnection
            )
            resultHandler(.errorLocal(error: error))
            return
        }

        if let error = completionRequest.error {
            var titleError: String = "Local error"
            var typeError: ErrorRequestLocal.ErrorRequestLocalType = .any

            if error._code == NSURLErrorTimedOut {
                titleError = NetworkResponseErrorString.outdated.rawValue
                typeError = .timeout
            }

            if error._code == NSURLErrorUnknown {
                titleError = NetworkResponseErrorString.failed.rawValue
                typeError = .any
            }

            if error._code == NSURLErrorBadURL {
                titleError = NetworkResponseErrorString.badRequest.rawValue
                typeError = .badRequest
            }

            let error = ErrorRequestLocal(
                title: titleError,
                message: error.localizedDescription,
                type: typeError
            )
            resultHandler(.errorLocal(error: error))
        }
    }

    func parserError<T>(data: Data?, error: Error?, result: ResultRequest<T>) {
        let error = ErrorRequestLocal(
            title: "Ошибка парсера",
            message: "Ошибка парсера",
            type: .errorParser
        )
        result(.errorLocal(error: error))
    }
    
}

// MARK: -
fileprivate extension Data {
    var prettyPrintedJSONString: NSString? { /// NSString gives us a nice sanitized debugDescription
        guard let object = try? JSONSerialization.jsonObject(with: self, options: []),
              let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted]),
              let prettyPrintedString = NSString(data: data, encoding: String.Encoding.utf8.rawValue) else { return nil }

        return prettyPrintedString
    }
}
