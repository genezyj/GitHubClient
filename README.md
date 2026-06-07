# GitHubClient iOS

A native iOS GitHub client built with Swift and UIKit. The app lets you browse
popular Swift repositories, search GitHub, view repository details, and sign in
with GitHub using OAuth + PKCE.

I built this project to explore a practical UIKit architecture for a small,
API-driven app: protocol-based services, MVVM view models, reusable UI
components, secure token storage, and testable networking/authentication flows.

## Features

- Browse popular Swift repositories without signing in
- Search GitHub repositories by keyword
- View repository details, topics, stars, forks, open issues, and owner info
- Open repositories in GitHub with `SFSafariViewController`
- Sign in with GitHub via OAuth Authorization Code + PKCE
- View the authenticated GitHub profile with `GET /user`
- Store OAuth access tokens securely in the Keychain
- Restore a saved session with Face ID / Touch ID local unlock
- Log out locally or remove the saved token from the device
- Reusable avatar, repository card, stat badge, loading, empty, and error views
- Pull to refresh and paginated repository lists
- Light and dark mode support
- Simplified Chinese localization
- iPhone and iPad layouts

## Tech Stack

- Swift, UIKit, programmatic Auto Layout, `UIStackView`
- MVVM with a lightweight `AppCoordinator`
- `URLSession` behind `APIClientProtocol`
- `AuthenticationServices` for `ASWebAuthenticationSession`
- `CryptoKit` for PKCE code verifier and S256 code challenge generation
- `LocalAuthentication` for Face ID / Touch ID local unlock
- Swift Package Manager dependencies:
  - [SnapKit](https://github.com/SnapKit/SnapKit) for the login screen layout
  - [Kingfisher](https://github.com/onevcat/Kingfisher) for remote avatar images
  - [KeychainAccess](https://github.com/kishikawakatsumi/KeychainAccess) for token storage
- XCTest and XCUITest

The external packages are intentionally scoped:

| Package | Used for |
| ------- | -------- |
| SnapKit | `LoginViewController` layout |
| Kingfisher | Avatar loading inside `AvatarImageView` |
| KeychainAccess | OAuth token persistence in `KeychainSecureStorage` |

## Architecture

```text
GitHubClient/
 ├── App/                 AppDelegate, SceneDelegate, tab bar, coordinator
 ├── Core/
 │    ├── Auth/           OAuth, PKCE, session, biometrics
 │    ├── Models/         GitHubUser, GitHubRepository, RepositoryOwner
 │    ├── Networking/     Endpoint, APIClient, AppError
 │    ├── Services/       GitHubService
 │    ├── State/          ViewState<Value>
 │    ├── Storage/        SecureStorage, KeychainSecureStorage
 │    └── Utilities/      L10n, Formatters
 ├── Features/
 │    ├── Home/
 │    ├── Search/
 │    ├── Profile/
 │    ├── Login/
 │    └── RepositoryDetail/
 ├── Resources/zh-Hans.lproj/
 └── UIComponents/
```

View controllers focus on view setup, binding, and navigation. View models own
feature state and service calls, exposing a single `ViewState<Value>` to the
UI. Networking, GitHub API access, OAuth, secure storage, and biometrics all sit
behind protocols so they can be tested with mocks.

The scene manifest and OAuth URL scheme are configured in
`SupportingFiles/GitHubClient-Info.plist`. The app registers the custom URL
scheme `githubclient` for the redirect URL:

```text
githubclient://oauth/callback
```

## OAuth Login

The app uses GitHub OAuth Authorization Code flow with PKCE through
`ASWebAuthenticationSession`. It does not ask users to paste a Personal Access
Token, and it does not implement username/password login because GitHub's REST
API does not support basic password authentication for this use case.

OAuth is handled by `GitHubClient/Core/Auth/OAuthService.swift`:

1. Generate a new PKCE `code_verifier`, S256 `code_challenge`, and random
   `state`.
2. Open GitHub's authorization URL in `ASWebAuthenticationSession`.
3. Receive the `githubclient://oauth/callback` redirect.
4. Validate that the returned `state` matches the generated state.
5. Exchange the authorization code for an OAuth access token.
6. Save the token with `KeychainSecureStorage`.
7. Validate the token with `GET /user` and update the profile screen.

Access tokens are sent as `Authorization: Bearer <token>` only for
authenticated requests. They are not stored in `UserDefaults`, printed in logs,
or hardcoded in source.

### GitHub OAuth App Setup

Home and Search work immediately in guest mode. To enable sign in, create a
GitHub OAuth App:

1. Open <https://github.com/settings/developers>.
2. Go to **OAuth Apps** -> **New OAuth App**.
3. Use any application name, for example `GitHubClient iOS`.
4. Set **Homepage URL** to `https://github.com`.
5. Set **Authorization callback URL** to:

   ```text
   githubclient://oauth/callback
   ```

6. Copy the Client ID and generate a new client secret.
7. Replace the placeholders in `GitHubClient/Core/Auth/OAuthConfig.swift`:

   ```swift
   static let clientID = "<your client id>"
   static let clientSecret = "<your client secret>"
   ```

The login screen disables the GitHub sign-in button until those placeholders
are replaced.

### Production Note

A native iOS app cannot keep a client secret truly private. For a production
app, the authorization-code exchange should happen on a backend service so the
secret never ships inside the app bundle. This project keeps the exchange in
the app to make the sample self-contained.

## Biometric Local Unlock

After a successful OAuth login, the token remains in the Keychain. If the user
logs out locally but keeps the saved token, the Profile tab can offer Face ID /
Touch ID unlock on supported devices.

The biometric flow:

1. Prompt with `LAContext.evaluatePolicy`.
2. Read the saved OAuth token from the Keychain after a successful local
   biometric check.
3. Validate the token with `GET /user`.
4. Restore the in-app authenticated session.

Biometrics are only a local unlock mechanism. GitHub authentication still uses
OAuth.

## How to Run

1. Open `GitHubClient.xcodeproj` in Xcode 16 or newer.
2. Select the `GitHubClient` scheme.
3. Choose an iOS Simulator or connected device.
4. Run the app.

The app launches in guest mode, so repository browsing and search work without
OAuth setup.

To test the full authentication flow:

1. Complete the GitHub OAuth App setup above.
2. Open the Profile tab.
3. Tap `使用 GitHub 登录`.
4. Authorize the app on GitHub.
5. Return to the app and confirm that the Profile tab shows the authenticated
   user.
6. Log out locally and use Face ID / Touch ID to restore the saved session.

## Testing

Unit tests cover endpoints, JSON decoding, search view-model state, auth
session restoration, logout behavior, and Keychain storage. UI tests cover the
main launch flow.

Run tests from Xcode with `Command-U`, or from the command line:

```bash
xcodebuild -project GitHubClient.xcodeproj \
  -scheme GitHubClient \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  test
```

Focused unit-test files include:

- `EndpointTests`
- `GitHubRepositoryDecodingTests`
- `SearchViewModelTests`
- `AuthServiceTests`
- `KeychainSecureStorageTests`
- `GitHubClientTests`

Mocks live in `GitHubClientTests/Mocks/TestMocks.swift`.

## Localization

The app currently ships Simplified Chinese (`zh-Hans`) strings. The development
region is also set to `zh-Hans`, so Chinese text is used as the fallback when
the device language does not have a dedicated localization.

To switch a simulator to Chinese:

```text
Settings -> General -> Language & Region -> iPhone Language -> 简体中文
```

## Known Limitations

- GitHub OAuth sign in requires a locally configured OAuth App client ID and
  client secret.
- The OAuth token exchange happens on-device for simplicity. A production app
  should move this exchange to a backend.
- The app currently focuses on repository browsing, search, details, and
  profile display; repository creation, issue management, starring, and other
  write actions are not implemented.
- TestFlight distribution and release signing setup are not included.
- The UI is UIKit-only; there is no SwiftUI implementation in this project.

---

# GitHubClient iOS（中文说明）

一个使用 Swift 和 UIKit 编写的原生 iOS GitHub 客户端。它支持浏览热门 Swift
仓库、搜索 GitHub、查看仓库详情，并通过 OAuth + PKCE 登录 GitHub。

这个项目主要用于实践一个小型 API 驱动 iOS 应用的完整结构：基于协议的服务层、
MVVM ViewModel、可复用 UI 组件、安全令牌存储，以及可测试的网络和登录流程。

## 功能

- 未登录状态下浏览热门 Swift 仓库
- 按关键词搜索 GitHub 仓库
- 查看仓库详情、topics、star、fork、open issues 和作者信息
- 使用 `SFSafariViewController` 打开 GitHub 原始页面
- 通过 OAuth Authorization Code + PKCE 登录 GitHub
- 登录后通过 `GET /user` 展示个人资料
- 使用 Keychain 安全保存 OAuth access token
- 使用 Face ID / Touch ID 本地解锁已保存会话
- 支持本地退出登录，或同时移除本机保存的 token
- 可复用头像、仓库卡片、统计徽章、加载、空状态和错误状态组件
- 下拉刷新与分页加载
- 浅色和深色模式
- 简体中文本地化
- iPhone 与 iPad 布局适配

## 技术栈

- Swift、UIKit、纯代码 Auto Layout、`UIStackView`
- MVVM 与轻量 `AppCoordinator`
- 在 `APIClientProtocol` 之后封装 `URLSession`
- 使用 `AuthenticationServices` 的 `ASWebAuthenticationSession`
- 使用 `CryptoKit` 生成 PKCE verifier 和 S256 challenge
- 使用 `LocalAuthentication` 完成 Face ID / Touch ID 本地解锁
- Swift Package Manager 依赖：
  - [SnapKit](https://github.com/SnapKit/SnapKit)：登录页布局
  - [Kingfisher](https://github.com/onevcat/Kingfisher)：远程头像加载
  - [KeychainAccess](https://github.com/kishikawakatsumi/KeychainAccess)：token 存储
- XCTest 与 XCUITest

## 架构

```text
GitHubClient/
 ├── App/                 AppDelegate、SceneDelegate、TabBar、Coordinator
 ├── Core/
 │    ├── Auth/           OAuth、PKCE、Session、生物识别
 │    ├── Models/         GitHubUser、GitHubRepository、RepositoryOwner
 │    ├── Networking/     Endpoint、APIClient、AppError
 │    ├── Services/       GitHubService
 │    ├── State/          ViewState<Value>
 │    ├── Storage/        SecureStorage、KeychainSecureStorage
 │    └── Utilities/      L10n、Formatters
 ├── Features/
 │    ├── Home/
 │    ├── Search/
 │    ├── Profile/
 │    ├── Login/
 │    └── RepositoryDetail/
 ├── Resources/zh-Hans.lproj/
 └── UIComponents/
```

ViewController 负责视图搭建、状态绑定和导航。ViewModel 负责功能状态与服务调用，
并向 UI 暴露统一的 `ViewState<Value>`。网络、GitHub API、OAuth、安全存储和生物
识别都通过协议注入，方便使用 mock 进行测试。

Scene 配置和 OAuth URL scheme 位于 `SupportingFiles/GitHubClient-Info.plist`。
应用注册的回调地址为：

```text
githubclient://oauth/callback
```

## GitHub OAuth 配置

首页和搜索可以直接以访客模式使用。若要启用登录，需要创建一个 GitHub OAuth App：

1. 打开 <https://github.com/settings/developers>。
2. 进入 **OAuth Apps** -> **New OAuth App**。
3. Application name 可任意填写，例如 `GitHubClient iOS`。
4. Homepage URL 填写 `https://github.com`。
5. Authorization callback URL 填写：

   ```text
   githubclient://oauth/callback
   ```

6. 复制 Client ID，并生成新的 client secret。
7. 替换 `GitHubClient/Core/Auth/OAuthConfig.swift` 中的占位符：

   ```swift
   static let clientID = "<your client id>"
   static let clientSecret = "<your client secret>"
   ```

占位符未替换前，登录页会禁用 GitHub 登录按钮。

### 生产环境说明

原生 iOS 应用无法真正保护 client secret。生产应用应将 authorization code 换 token
的请求放到后端服务中，避免 secret 随 app bundle 下发。本项目为了保持示例完整，
将该流程保留在客户端。

## 如何运行

1. 使用 Xcode 16 或更新版本打开 `GitHubClient.xcodeproj`。
2. 选择 `GitHubClient` scheme。
3. 选择 iOS 模拟器或真机。
4. 运行应用。

应用默认以访客模式启动，因此不配置 OAuth 也可以浏览和搜索仓库。

完整登录流程：

1. 完成上面的 GitHub OAuth App 配置。
2. 打开 Profile 标签页。
3. 点击 `使用 GitHub 登录`。
4. 在 GitHub 页面同意授权。
5. 回到应用后确认 Profile 显示已登录用户。
6. 本地退出登录后，可使用 Face ID / Touch ID 恢复已保存会话。

## 测试

单元测试覆盖 endpoint 生成、JSON 解码、搜索 ViewModel 状态、登录会话恢复、退出
登录行为和 Keychain 存储。UI 测试覆盖主要启动流程。

可在 Xcode 中使用 `Command-U` 运行，也可以使用命令行：

```bash
xcodebuild -project GitHubClient.xcodeproj \
  -scheme GitHubClient \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  test
```

## 已知限制

- GitHub 登录需要本地配置 OAuth App 的 Client ID 和 client secret。
- 为了让项目自包含，OAuth token exchange 目前在客户端完成；生产环境应移到后端。
- 当前功能集中在仓库浏览、搜索、详情和个人资料展示，尚未实现创建仓库、issue 管理、
  star 等写操作。
- 未包含 TestFlight 分发和正式发布签名配置。
- 当前项目仅使用 UIKit，没有 SwiftUI 版本。
