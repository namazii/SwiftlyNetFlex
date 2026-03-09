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
//import CocoaLumberjackSwift

class Log {

    enum LogType {

        case verb
        case info
        case error
        case debug
        case warn

    }

    nonisolated(unsafe) static var isLoggerInit = false

    static func getLogString(type: LogType, message: String) -> String {
        let defaultPrefix: String = "[\(time())]: "
        var prefix = ""
        switch type {
        case .verb:
            prefix = "💜 VERBOSE\(defaultPrefix)"
        case .info:
            prefix = "💙 INFO\(defaultPrefix)"
        case .error:
            prefix = "❤️ ERROR\(defaultPrefix)"
        case .debug:
            prefix = "💚 DEBUG\(defaultPrefix)"
        case .warn:
            prefix = "💛 WARNING\(defaultPrefix)"
        }
        return prefix + message
    }

    static func time() -> String {
        let date = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        let result = formatter.string(from: date)
        return result
    }

    static func initLoger() {
//        DDLog.add(DDOSLogger.sharedInstance)
        isLoggerInit = true
    }

    static func warn(_ message: String) {
        if !isLoggerInit { initLoger() }
//        DDLogWarn(message)
        print(getLogString(type: .warn, message: message))
    }

    static func debug(_ message: String) {
        if !isLoggerInit { initLoger() }
//        DDLogDebug(message)
        print(getLogString(type: .debug, message: message))
    }

    static func error(_ message: String) {
        if !isLoggerInit { initLoger() }
//        DDLogError(message)
        print(getLogString(type: .error, message: message))
    }

    static func info(_ message: String) {
        if !isLoggerInit { initLoger() }
//        DDLogInfo(message)
        print(getLogString(type: .info, message: message))
    }

    static func verb(_ message: String) {
        if !isLoggerInit { initLoger() }
//        DDLogVerbose(message)
        print(getLogString(type: .verb, message: message))
    }

}
