# SwiftlyNetFlex

`SwiftlyNetFlex` is a lightweight networking layer for iOS projects using Swift Package Manager.

## Features

- Typed request/response handling with `Codable`
- Async/await and callback-style APIs
- Flexible endpoint and task builders
- URL and JSON parameter encoding
- Token refresh flow support (`TokenAuthorizator`)
- Network state monitoring via `NWPathMonitor`

## Installation

Add dependency in Xcode (`File -> Add Packages...`) or in `Package.swift`:

```swift
.package(url: "https://github.com/<YOUR_GITHUB_USERNAME>/SwiftlyNetFlex.git", from: "1.0.0")
```

And connect the product to your target:

```swift
.product(name: "SwiftlyNetFlex", package: "SwiftlyNetFlex")
```

## Usage

### 1. Create token model and refresh configuration

```swift
import Foundation
import SwiftlyNetFlex

struct AuthTokens: TokenModelProtocol {
    var accessToken: String
    var refreshToken: String
}

struct RefreshConfig: TokenRefreshConfiguration {
    typealias ResponseType = AuthTokens

    func getRefreshToken() -> String? {
        UserDefaults.standard.string(forKey: "refresh_token")
    }

    func makeRefreshTokenEndpoint(refreshToken: String) -> EndPointType {
        EndPointBuilder(
            baseUrl: "https://api.example.com",
            path: "/auth/refresh",
            httpMethod: .post,
            headers: ["Content-Type": "application/json"],
            bodyParam: ["refreshToken": refreshToken]
        ).build()
    }

    func saveTokens(_ token: AuthTokens) {
        UserDefaults.standard.set(token.accessToken, forKey: "access_token")
        UserDefaults.standard.set(token.refreshToken, forKey: "refresh_token")
    }

    var onTokenRefreshFailed: (() -> Void)? {
        { print("Refresh token failed, logout user") }
    }
}
```

### 2. Build endpoint and router

```swift
import SwiftlyNetFlex

let endpoint = EndPointBuilder(
    baseUrl: "https://api.example.com",
    path: "/v1/profile",
    httpMethod: .get,
    headers: ["Authorization": "Bearer <access_token>"],
    urlParam: ["lang": "en"]
).build()

let router = NetworkRouter<RefreshConfig>(refreshTokenConfigurator: RefreshConfig())
```

### 3. Perform request (async/await)

```swift
struct Profile: Codable, Sendable {
    let id: Int
    let name: String
}

do {
    let profile: Profile = try await router.request(Profile.self, endpoint)
    print(profile)
} catch {
    print(error)
}
```

### 4. Perform request (completion)

```swift
router.request(endpoint) { (result: ResultRequestCase<Profile>) in
    switch result {
    case .success(let profile):
        print(profile)
    case .errorNetwork(let error):
        print("Network error: \(error.title)")
    case .errorLocal(let error):
        print("Local error: \(error.title)")
    }
}
```

### 5. Start network monitoring

```swift
NetworkMonitor.shared.startMonitoring()
```

## License

MIT License

Copyright (c) 2026 Nazar Tkacenko

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
