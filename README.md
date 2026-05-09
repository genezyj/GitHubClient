# GitHubClient iOS

## Overview

A native iOS GitHub client built with Swift and UIKit (programmatic, no
Storyboards). Core features align with **`PROJECT_SPEC.md`**; **login** follows
**`OAUTH_SPEC.md`** (OAuth + PKCE, no manual PAT entry).

- Guest browsing without login
- Popular Swift repositories on Home
- Repository search
- **Sign in with GitHub** (OAuth Authorization Code + PKCE via `ASWebAuthenticationSession`)
- Authenticated profile (`GET /user` after OAuth)
- Logout
- Face ID / Touch ID local unlock for a previously saved **OAuth access token**
- Secure Keychain storage for that token (KeychainAccess)
- Reusable avatar image component
- Unified loading / empty / error states
- Light & dark mode
- Simplified Chinese (`zh-Hans`) localization
- iPhone & iPad layout

## Tech Stack

- Swift, UIKit — mostly programmatic Auto Layout (`NSLayoutConstraint`,
  `UIStackView`); **Login** additionally uses [**SnapKit**](https://github.com/SnapKit/SnapKit) for constraints.
- MVVM + lightweight composition root (`AppCoordinator`)
- Native `URLSession` behind `APIClientProtocol`
- **AuthenticationServices** — `ASWebAuthenticationSession` for GitHub OAuth; **CryptoKit** for PKCE (`code_verifier` / S256 `code_challenge`)
- [**KeychainAccess**](https://github.com/kishikawakatsumi/KeychainAccess) behind `SecureStorageProtocol` — `KeychainSecureStorage` stores the OAuth token with `afterFirstUnlockThisDeviceOnly` (same intent as the previous `SecItem*` implementation).
- [**Kingfisher**](https://github.com/onevcat/Kingfisher) — avatar URLs only, inside `AvatarImageView` (`kf.setImage` + cache/fade).
- `LocalAuthentication` (`LAContext`) for biometrics (unlocks saved token only)
- Custom URL scheme **`githubclient`** registered in `SupportingFiles/GitHubClient-Info.plist` for `githubclient://oauth/callback`
- Swift Package Manager: SnapKit, Kingfisher, KeychainAccess (`Package.resolved` under the `.xcodeproj` workspace shared data).
- `XCTest` (`EndpointTests`, `GitHubRepositoryDecodingTests`, `SearchViewModelTests`, `AuthServiceTests`, `KeychainSecureStorageTests`, plus `GitHubClientTests` sanity — see **P1.4**) and **XCUITest** (P2.1).

### Spec libraries — targeted adoption

PROJECT_SPEC mentions SnapKit / Kingfisher / KeychainAccess. This codebase uses **only where it pays off**:

| Package | Scope in this repo |
| ------- | ------------------ |
| **SnapKit** | `LoginViewController` layout only (`snp.makeConstraints`). Other screens remain UIKit constraints. |
| **Kingfisher** | `AvatarImageView` only (list avatars + profile/detail). |
| **KeychainAccess** | `KeychainSecureStorage.swift` only (`SecureStorageProtocol` unchanged for `AuthService` / tests). |

## Architecture

```
App
 ├── App/                 — AppDelegate, SceneDelegate, MainTabBarController, AppCoordinator
 ├── Core/
 │    ├── Models/         — GitHubUser, GitHubRepository, RepositoryOwner, …
 │    ├── Networking/     — Endpoint, HTTPMethod, APIClient(+Protocol), AppError
 │    ├── Services/       — GitHubService(+Protocol)
 │    ├── Auth/           — AuthService(+Protocol), OAuthService(+Protocol), OAuthConfig, PKCE.swift,
 │    │                    BiometricAuthService(+Protocol), AuthSession
 │    ├── Storage/        — SecureStorage(+Protocol), KeychainSecureStorage
 │    ├── State/          — ViewState<Value>
 │    └── Utilities/      — L10n, Formatters
 ├── Features/
 │    ├── Home/             — HomeViewController + HomeViewModel
 │    ├── Search/           — SearchViewController + SearchViewModel
 │    ├── Profile/          — ProfileViewController + ProfileViewModel
 │    ├── Login/            — LoginViewController + LoginViewModel
 │    └── RepositoryDetail/ — RepositoryDetailViewController + RepositoryDetailViewModel  (P1.1)
 ├── UIComponents/        — AvatarImageView (Kingfisher), RepositoryCardView, RepositoryListCell, StatBadgeView,
 │                          ErrorStateView, EmptyStateView, LoadingView
 └── Resources/zh-Hans.lproj/Localizable.strings
```

`SupportingFiles/GitHubClient-Info.plist` (outside the synced `GitHubClient/`
folder so it is not copied as a bundle resource) is merged into the built
`Info.plist`: main-window `SceneDelegate` wiring plus `CFBundleURLTypes` /
URL scheme **`githubclient`** for the OAuth redirect
(`githubclient://oauth/callback`).

ViewControllers do **view setup + state binding + navigation only**.
ViewModels own the service calls and expose a single `ViewState<Value>`. All
external dependencies (`APIClient`, `GitHubService`, `AuthService`, `OAuthService`,
the `SecureStorage`, biometrics) sit behind protocols, so each ViewModel is unit-
testable with mocks.

## Login Method

This demo uses **Sign in with GitHub (OAuth Authorization Code + PKCE)**
via `ASWebAuthenticationSession`. The user never copy-pastes a Personal
Access Token; tapping `使用 GitHub 登录` opens the official GitHub
authorization page, the system handles the `githubclient://oauth/callback`
redirect, and the app exchanges the returned code for an OAuth bearer token.

GitHub username + password is intentionally **not** implemented — the
GitHub REST API does not accept basic auth.

OAuth flow handled by `OAuthService` (`GitHubClient/Core/Auth/OAuthService.swift`):

1. Generate a fresh PKCE pair (`code_verifier` + SHA-256 `code_challenge`)
   and a random `state` (`PKCE.generate()` / `PKCE.generateState()`).
2. Build the authorize URL with `client_id`, `redirect_uri`, `scope`,
   `state`, `code_challenge`, `code_challenge_method=S256`, `prompt=select_account`.
3. Open `ASWebAuthenticationSession(url:callbackURLScheme: "githubclient")`.
4. Validate `state` returned in the callback equals the locally generated
   one — abort with `.invalidOAuthState` on mismatch.
5. POST `code` + `code_verifier` (PKCE) + `client_id` + `client_secret` to
   `https://github.com/login/oauth/access_token`, parse the JSON token
   payload.
6. Save the access token via **KeychainAccess** in `KeychainSecureStorage`
   (generic-password item scoped by bundle service id, accessibility
   `afterFirstUnlockThisDeviceOnly`).
7. Validate the token with `GET /user` and update the Profile UI.

OAuth access-token handling:

- Sent as `Authorization: Bearer <token>` on authenticated requests.
- **Never** stored in `UserDefaults`, logged to the console, printed in
  headers, or hardcoded in source.
- **退出登录** ends the in-app session but **keeps** the OAuth token in Keychain
  so the user can return with Face ID / Touch ID. **退出并移除已保存的登录** in
  the same alert deletes the Keychain token. GitHub’s own browser cookies are
  unchanged (see `OAUTH_SPEC.md` / `ASWebAuthenticationSession`).

### Reviewer setup (one-time, ~2 minutes)

1. Visit <https://github.com/settings/developers> → **OAuth Apps** → **New OAuth App**.
2. Fill in:
   - Application name: anything (e.g. `GitHubClient iOS Demo`).
   - Homepage URL: `https://github.com`.
   - Authorization callback URL: **`githubclient://oauth/callback`** (must match exactly).
3. After creating, copy **Client ID**, generate a **new client secret**, and copy it.
4. Open `GitHubClient/Core/Auth/OAuthConfig.swift` and replace the two
   placeholder values:

   ```swift
   static let clientID = "<your client id>"
   static let clientSecret = "<your client secret>"
   ```

5. Run the app. The Login screen shows a clear inline message until those
   placeholders are replaced — the **Sign in with GitHub** button is
   disabled while the placeholders are still in place.

### Production caveat 

A native iOS app cannot truly keep `clientSecret` confidential, so a real
production build should move the token-exchange POST to a small backend
(Cloudflare Worker, Lambda, etc.) so the secret never ships in the app
bundle. Doing the exchange directly from the device is an explicit demo
compromise here.

## Biometric (Face ID / Touch ID) Local Unlock

After a successful OAuth login, the next time the user is in guest state
and the device supports biometrics, a `使用 Face ID / Touch ID 登录`
button appears on the Profile tab. Tapping it:

1. Prompts the user via `LAContext.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, …)`.
2. On success, reads the saved OAuth token from the Keychain.
3. Calls `GET /user` to validate and rebuild the session.

Biometrics are **local unlock** only — they never replace OAuth
authentication against GitHub.

`NSFaceIDUsageDescription` is set in the auto-generated `Info.plist` via
`INFOPLIST_KEY_NSFaceIDUsageDescription`.

## How to Run

1. Open `GitHubClient.xcodeproj` in Xcode 16 (or newer).
2. Select the `GitHubClient` scheme.
3. Choose any iOS Simulator (or a device) and run.

No Xcode or `.xcconfig` setup is required to **launch** the app — Home and
Search work in guest mode immediately.

To **sign in**, you must create a GitHub OAuth App once and paste **Client ID**
and **Client Secret** into `GitHubClient/Core/Auth/OAuthConfig.swift` (see the
reviewer checklist under **Login Method**). Until placeholders are replaced,
the Login screen disables **Sign in with GitHub** and shows an explanatory
inline message.

The Scene manifest lives in `SupportingFiles/GitHubClient-Info.plist` (outside
the synced `GitHubClient/` source folder) so Xcode does not copy it into the
app bundle as an extra resource yet still merges it into the processed
`Info.plist`. That file names `$(PRODUCT_MODULE_NAME).SceneDelegate` as the
delegate for the primary window scene—without that, the app can launch to a
black screen. Console lines such as `Failed to send CA Event for app launch
measurements` and `FBSSceneSnapshotErrorDomain` are common simulator noise and
are unrelated to this.

To exercise the full flow (after completing the OAuth setup above):

1. Open the **Profile** tab → `使用 GitHub 登录`.
2. Tap `使用 GitHub 登录` on the Login screen — the system opens the
   official GitHub authorization page.
3. Approve the app. You're returned to GitHubClient and the Profile screen
   updates to your authenticated GitHub user. The OAuth token is stored in
   the Keychain.
4. Tap `退出登录` on the Profile screen, then in the alert choose **`退出登录`**
   (sign out locally but keep the saved token). The Profile tab shows guest
   state; `使用 Face ID / Touch ID 登录` restores the session from Keychain
   without repeating OAuth. Use **`退出并移除已保存的登录`** when you want to
   remove the token from this device as well.

## Localization

Only Simplified Chinese (`zh-Hans`) is provided, per spec. The development
region is set to `zh-Hans` so Chinese strings are also used as the runtime
fallback when the system language is something else (e.g. English).

To switch a simulator to Chinese: `Settings → General → Language & Region →
iPhone Language → 简体中文`.

## Light / Dark Mode & Screen Sizes

- Only system colors (`.systemBackground`, `.label`, `.secondaryLabel`, etc.)
  are used.
- Profile and Login content is constrained to a max width (~600–700pt) so
  iPad doesn't stretch text awkwardly.
- Most layouts use safe area + `UIStackView` + Auto Layout; **Login**
  additionally uses SnapKit for the scroll / container / stack hierarchy.

## Completed (P0)

- App structure: `MainTabBarController` with Home / Search / Profile, each in
  its own `UINavigationController`.
- Guest mode: app launches straight into Home with no login required.
- Home: popular Swift repositories via `GET /search/repositories`.
- Search: keyword search via `GET /search/repositories`.
- Profile: guest & logged-in states.
- Login: OAuth (PKCE + `ASWebAuthenticationSession`), token exchange, then `GET /user`; access token stored in Keychain (`OAUTH_SPEC.md`).
- Logout with confirmation alert.
- Face ID / Touch ID local unlock.
- `AvatarImageView` reusable image component.
- `ErrorStateView` reusable error component (+ `EmptyStateView`,
  `LoadingView`).
- `ViewState<Value>` used by every feature ViewModel.
- All user-facing text comes from `Localizable.strings` via `L10n`.
- Light/Dark mode via system colors.
- iPhone & iPad layouts.

## Completed (P1)

### P1.1 Repository Detail page
Tapping a row on Home or Search pushes
`RepositoryDetailViewController`. The screen renders the model that was
already in memory, then `RepositoryDetailViewModel` fires
`GET /repos/{owner}/{repo}` to refresh fields the search payload omits
(notably `open_issues_count` and `topics`). Open-issues and topics show
when present; an **Open in GitHub** button opens the `html_url` in
`SFSafariViewController`. Errors keep the cached row visible rather than
blanking the UI.

### P1.2 Pagination
`HomeViewModel` and `SearchViewModel` both track:

```swift
private(set) var currentPage: Int
private(set) var isLoadingNextPage: Bool
private(set) var hasMore: Bool
```

`loadNextPageIfNeeded()` is invoked from
`tableView(_:willDisplay:forRowAt:)` when the row index is within the
last 5. Duplicate IDs are filtered. A bottom `UIActivityIndicatorView`
appears as `tableFooterView` while the next page is in flight, and the
list stops paginating once the API returns fewer items than `pageSize`.

### P1.3 Pull to refresh
`UIRefreshControl` is wired on both Home and Search. Pulling reloads the
first page, clears the accumulator and pagination state, and the spinner
hides as soon as the next non-loading state arrives.

### P1.4 Unit tests (XCTest)
Replaced the auto-generated Swift Testing stub with focused XCTest cases —
deliberately minimal, just enough to demonstrate XCTest:

- `EndpointTests` — verifies path / method / query items for repository
  search and detail endpoints.
- `GitHubRepositoryDecodingTests` — round-trips sample JSON through
  `JSONDecoder` (snake_case → camelCase, ISO-8601 dates, optional fields).
- `SearchViewModelTests` — `loading → loaded` happy path,
  `loading → error` failure path, and empty-query reset, all driven by a
  mock `GitHubServiceProtocol`.
- `AuthServiceTests` — `restoreSession` with a valid stored token, no
  token, an invalid token (throws `.unauthorized`), and `logout` clearing
  the keychain + in-memory user.
- `KeychainSecureStorageTests` — round-trip `save` / `read` / `delete` and
  overwrite behavior against the real **KeychainAccess** stack, using a
  unique `service` id per test so items never collide with the app’s
  production key.
- `GitHubClientTests` — `AppError` localized message smoke check.

Mocks live in `GitHubClientTests/Mocks/TestMocks.swift`. Tests run from
the IDE (`⌘U`) or from CLI:

```bash
xcodebuild -project GitHubClient.xcodeproj \
  -scheme GitHubClient \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:GitHubClientTests test
```

### P1.5 Capability / Entitlement
Enabled **Keychain Sharing** as the demonstration capability. The
entitlement file is `SupportingFiles/GitHubClient.entitlements` (kept
outside the synced source group so it isn't copied into the bundle as a
resource) and is wired through `CODE_SIGN_ENTITLEMENTS`. The access
group is `$(AppIdentifierPrefix)$(CFBundleIdentifier)` — i.e. the app's
own default group, so `KeychainSecureStorage` does **not** need to set
`kSecAttrAccessGroup` at runtime and behavior is identical to before.

If automatic signing on a different team rejects this entitlement,
remove the `CODE_SIGN_ENTITLEMENTS` line from both Debug and Release
configurations of the `GitHubClient` target — the Keychain still works
because items default to the app's own access group. Per
`PROJECT_SPEC.md` §P1.5, signing problems should not block the project.

### P1.6 Custom components
Added `StatBadgeView` (icon + value pill) and refactored
`RepositoryCardView` to use it for stars and forks. The full set of
reusable components is now:

```
AvatarImageView      (Kingfisher for remote images)
RepositoryCardView   (consumed by Home + Search list cells and the detail header)
StatBadgeView        (consumed by RepositoryCardView and RepositoryDetailViewController)
ErrorStateView
EmptyStateView
LoadingView
```

## Completed (P2)

UITests


## Known Limitations

- SnapKit / Kingfisher / KeychainAccess are used in **narrow** places only
  (login layout, avatar loading, token storage); the rest of the UI and
  networking is still vanilla UIKit + `URLSession`.
- **`clientSecret` in the app bundle** — a native binary cannot keep a OAuth
  client secret truly private. This project exchanges the authorization code
  on-device per `OAUTH_SPEC.md`; production builds should proxy that POST
  through a backend (same note under **Production caveat** in **Login Method**).
- TestFlight distribution is not included. The app can be archived and
  uploaded with a valid Apple Developer account.
- No SwiftUI usage in this project.

---

# GitHubClient iOS（中文说明）

## 概述

使用 Swift 与 UIKit 编写的原生 iOS GitHub 客户端（纯代码布局，无 Storyboard）。核心功能与 **`PROJECT_SPEC.md`** 一致；**登录** 遵循 **`OAUTH_SPEC.md`**（OAuth + PKCE，不支持手动输入 PAT）。

- 未登录即可以访客身份浏览
- 首页展示热门 Swift 仓库
- 仓库搜索
- **使用 GitHub 登录**（通过 `ASWebAuthenticationSession` 的 OAuth 授权码 + PKCE）
- 登录后可查看个人资料（OAuth 后 `GET /user`）
- 退出登录
- 针对已保存的 **OAuth 访问令牌** 提供 Face ID / Touch ID 本地解锁
- 使用 Keychain 安全保存该令牌（KeychainAccess）
- 可复用的头像图片组件
- 统一的加载 / 空状态 / 错误状态
- 浅色与深色模式
- 简体中文（`zh-Hans`）本地化
- 适配 iPhone 与 iPad 布局

## 技术栈

- Swift、UIKit — 以程序化 Auto Layout（`NSLayoutConstraint`、`UIStackView`）为主；**登录页** 额外使用 [**SnapKit**](https://github.com/SnapKit/SnapKit) 处理约束。
- MVVM + 轻量组合根（`AppCoordinator`）
- 在 `APIClientProtocol` 之下封装原生 `URLSession`
- **AuthenticationServices** — 使用 `ASWebAuthenticationSession` 完成 GitHub OAuth；**CryptoKit** 实现 PKCE（`code_verifier` / S256 `code_challenge`）
- 在 `SecureStorageProtocol` 之后接入 [**KeychainAccess**](https://github.com/kishikawakatsumi/KeychainAccess) — `KeychainSecureStorage` 以 `afterFirstUnlockThisDeviceOnly` 保存 OAuth 令牌（语义与原先 `SecItem*` 实现一致）。
- [**Kingfisher**](https://github.com/onevcat/Kingfisher) — 仅用于头像 URL，在 `AvatarImageView` 内（`kf.setImage` + 缓存/渐入）。
- 生物识别使用 `LocalAuthentication`（`LAContext`）（仅解锁已保存的令牌）
- 在 `SupportingFiles/GitHubClient-Info.plist` 注册自定义 URL Scheme **`githubclient`**，用于 `githubclient://oauth/callback`
- Swift Package Manager：SnapKit、Kingfisher、KeychainAccess（版本见 `.xcodeproj` workspace 共享数据中的 `Package.resolved`）。
- `XCTest`（`EndpointTests`、`GitHubRepositoryDecodingTests`、`SearchViewModelTests`、`AuthServiceTests`、`KeychainSecureStorageTests`，以及 `GitHubClientTests` 冒烟 — 见 **P1.4**）与 **XCUITest**（P2.1）。

### 规格中的库 — 有选择地使用

PROJECT_SPEC 提及 SnapKit / Kingfisher / KeychainAccess。本仓库 **仅在值得处** 引用：

| 包 | 在本仓库中的范围 |
| ------- | ------------------ |
| **SnapKit** | 仅 `LoginViewController` 布局（`snp.makeConstraints`）。其余界面仍为 UIKit 约束。 |
| **Kingfisher** | 仅 `AvatarImageView`（列表头像与资料/详情）。 |
| **KeychainAccess** | 仅 `KeychainSecureStorage.swift`（面向 `AuthService` / 测试的 `SecureStorageProtocol` 未改）。 |

## 架构

```
App
 ├── App/                 — AppDelegate、SceneDelegate、MainTabBarController、AppCoordinator
 ├── Core/
 │    ├── Models/         — GitHubUser、GitHubRepository、RepositoryOwner、…
 │    ├── Networking/     — Endpoint、HTTPMethod、APIClient(+Protocol)、AppError
 │    ├── Services/       — GitHubService(+Protocol)
 │    ├── Auth/           — AuthService(+Protocol)、OAuthService(+Protocol)、OAuthConfig、PKCE.swift、
 │    │                    BiometricAuthService(+Protocol)、AuthSession
 │    ├── Storage/        — SecureStorage(+Protocol)、KeychainSecureStorage
 │    ├── State/          — ViewState<Value>
 │    └── Utilities/      — L10n、Formatters
 ├── Features/
 │    ├── Home/             — HomeViewController + HomeViewModel
 │    ├── Search/           — SearchViewController + SearchViewModel
 │    ├── Profile/          — ProfileViewController + ProfileViewModel
 │    ├── Login/            — LoginViewController + LoginViewModel
 │    └── RepositoryDetail/ — RepositoryDetailViewController + RepositoryDetailViewModel  (P1.1)
 ├── UIComponents/        — AvatarImageView（Kingfisher）、RepositoryCardView、RepositoryListCell、StatBadgeView、
 │                          ErrorStateView、EmptyStateView、LoadingView
 └── Resources/zh-Hans.lproj/Localizable.strings
```

`SupportingFiles/GitHubClient-Info.plist`（位于未同步进 `GitHubClient/` 源目录的位置，避免被当作 bundle 资源复制）会合并进构建产物的  
`Info.plist`：主窗口的 `SceneDelegate` 关联，以及 OAuth 重定向用的 URL Scheme **`githubclient`**（`githubclient://oauth/callback`）。

ViewController **只负责** 视图搭建、状态绑定与导航。  
ViewModel 负责调用服务并对外暴露统一的 `ViewState<Value>`。  
`APIClient`、`GitHubService`、`AuthService`、`OAuthService`、`SecureStorage`、生物识别等外部依赖均通过协议注入，便于用 mock 对 ViewModel 做单元测试。

## 登录方式

本示例通过 `ASWebAuthenticationSession` 使用 **GitHub 登录（OAuth 授权码 + PKCE）**。用户无需复制粘贴 Personal Access Token；点击「使用 GitHub 登录」会打开 GitHub 官方授权页，系统处理 `githubclient://oauth/callback` 回调，应用再将返回的 code 换为 OAuth Bearer Token。

GitHub **用户名 + 密码** 登录 **刻意未实现** — GitHub REST API 不支持以 Basic Auth 替代 OAuth。

OAuth 流程由 `OAuthService`（`GitHubClient/Core/Auth/OAuthService.swift`）处理：

1. 生成新的 PKCE 对（`code_verifier` + SHA-256 `code_challenge`）与随机 `state`（`PKCE.generate()` / `PKCE.generateState()`）。
2. 组装授权 URL，包含 `client_id`、`redirect_uri`、`scope`、`state`、`code_challenge`、`code_challenge_method=S256`、`prompt=select_account`。
3. 打开 `ASWebAuthenticationSession(url:callbackURLScheme: "githubclient")`。
4. 校验回调中的 `state` 与本地生成值一致 — 不一致则中止并报 `.invalidOAuthState`。
5. 向 `https://github.com/login/oauth/access_token` POST `code` + `code_verifier`（PKCE）+ `client_id` + `client_secret`，解析 JSON 中的 token。
6. 通过 **KeychainAccess** 在 `KeychainSecureStorage` 中保存访问令牌（按 bundle 的 service 区分的 generic-password，可访问性为 `afterFirstUnlockThisDeviceOnly`）。
7. 使用 `GET /user` 校验令牌并更新「我的」界面。

OAuth 访问令牌处理：

- 在需要认证的请求中以 `Authorization: Bearer <token>` 发送。
- **绝不**写入 `UserDefaults`、打印到控制台、出现在日志头或写死在源码中。
- **「退出登录」** 结束应用内会话，但 **保留** Keychain 中的 OAuth 令牌，以便用户通过 Face ID / Touch ID 再次进入。同一弹窗中的 **「退出并移除已保存的登录」** 会删除 Keychain 中的令牌。GitHub 在浏览器侧的 Cookie 不受影响（见 `OAUTH_SPEC.md` / `ASWebAuthenticationSession`）。

### 审阅者一次性配置（约 2 分钟）

1. 打开 <https://github.com/settings/developers> → **OAuth Apps** → **New OAuth App**。
2. 填写：
   - Application name：任意（例如 `GitHubClient iOS Demo`）。
   - Homepage URL：`https://github.com`。
   - Authorization callback URL：**`githubclient://oauth/callback`**（须完全一致）。
3. 创建后复制 **Client ID**，生成 **新的 client secret** 并复制。
4. 打开 `GitHubClient/Core/Auth/OAuthConfig.swift`，替换两处占位符：

   ```swift
   static let clientID = "<your client id>"
   static let clientSecret = "<your client secret>"
   ```

5. 运行应用。在占位符替换前，登录页会显示明确提示 —— **「使用 GitHub 登录」** 在仍为占位符时保持禁用。

### 生产环境注意

原生 iOS 应用无法真正隐藏 `clientSecret`，因此生产环境应将换 token 的 POST 放到小型后端（Cloudflare Worker、Lambda 等），避免密钥打进应用包。在设备上直接换 token 在本项目中为 **刻意的演示折衷**。

## 生物识别（Face ID / Touch ID）本地解锁

OAuth 登录成功后，当用户处于访客状态且设备支持生物识别时，「我的」页会出现 **「使用 Face ID / Touch ID 登录」** 按钮。点击后：

1. 通过 `LAContext.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, …)` 提示用户。
2. 成功后从 Keychain 读取已保存的 OAuth 令牌。
3. 调用 `GET /user` 校验并恢复会话。

生物识别 **仅为本地解锁**，不能替代面向 GitHub 的 OAuth 认证。

通过 `INFOPLIST_KEY_NSFaceIDUsageDescription` 在自动生成的 `Info.plist` 中设置 `NSFaceIDUsageDescription`。

## 如何运行

1. 用 Xcode 16（或更新）打开 `GitHubClient.xcodeproj`。
2. 选择 `GitHubClient` scheme。
3. 任选 iOS 模拟器（或真机）并运行。

**启动**应用无需额外 Xcode 或 `.xcconfig` 配置 —— 首页与搜索可立即以访客模式使用。

要 **登录**，需先创建一次 GitHub OAuth App，并将 **Client ID** 与 **Client Secret** 填入 `GitHubClient/Core/Auth/OAuthConfig.swift`（见上文 **登录方式** 中的审阅清单）。占位符未替换前，登录页会禁用「使用 GitHub 登录」并显示说明。

Scene 配置位于 `SupportingFiles/GitHubClient-Info.plist`（在同步的 `GitHubClient/` 源码外），因此不会作为多余资源拷贝进 bundle，仍会合并进最终 `Info.plist`。其中将 `$(PRODUCT_MODULE_NAME).SceneDelegate` 设为主窗口场景的委托 —— 若缺失可能导致启动黑屏。控制台如 `Failed to send CA Event for app launch measurements`、`FBSSceneSnapshotErrorDomain` 等多为模拟器噪音，与本体无关。

完成 OAuth 配置后，可按下列步骤走通完整流程：

1. 打开 **「我的」** 标签页 → 「使用 GitHub 登录」。
2. 在登录页再点「使用 GitHub 登录」— 系统会打开 GitHub 官方授权页。
3. 同意授权。返回 GitHubClient 后「我的」会显示你的 GitHub 用户；OAuth 令牌写入 Keychain。
4. 在「我的」点击「退出登录」，在弹窗中选择 **「退出登录」**（仅结束本地会话但 **保留** 已保存的令牌）。此时为访客状态；**「使用 Face ID / Touch ID 登录」** 可从 Keychain 恢复会话而无需再次 OAuth。若需同时从本机删除令牌，请选择 **「退出并移除已保存的登录」**。

## 本地化

按规格仅提供简体中文（`zh-Hans`）。开发地区设为 `zh-Hans`，因此系统为其他语言时，运行时回退也会优先使用中文文案。

将模拟器改为中文：`设置 → 通用 → 语言与地区 → iPhone 语言 → 简体中文`。

## 浅色 / 深色模式与屏幕尺寸

- 使用系统颜色（`.systemBackground`、`.label`、`.secondaryLabel` 等）。
- 「我的」与登录内容限制最大宽度（约 600–700pt），避免 iPad 上文字拉得过宽。
- 多数布局使用安全区 + `UIStackView` + Auto Layout；**登录页** 的滚动/容器/栈额外使用 SnapKit。

## 已完成（P0）

- 应用结构：`MainTabBarController` 下 Home / Search / Profile，各自 `UINavigationController`。
- 访客模式：启动即进入首页，无需登录。
- 首页：通过 `GET /search/repositories` 展示热门 Swift 仓库。
- 搜索：通过 `GET /search/repositories` 关键词搜索。
- 「我的」：访客与已登录状态。
- 登录：OAuth（PKCE + `ASWebAuthenticationSession`）、换 token、再 `GET /user`；访问令牌存 Keychain（`OAUTH_SPEC.md`）。
- 带确认弹窗的退出登录。
- Face ID / Touch ID 本地解锁。
- 可复用 `AvatarImageView`。
- 可复用 `ErrorStateView`（以及 `EmptyStateView`、`LoadingView`）。
- 各功能 ViewModel 均使用 `ViewState<Value>`。
- 面向用户的文案经 `Localizable.strings` 与 `L10n`。
- 系统颜色支持浅色/深色。
- iPhone 与 iPad 布局。

## 已完成（P1）

### P1.1 仓库详情页
在首页或搜索点击行会 push `RepositoryDetailViewController`。界面先展示内存中已有模型，再由 `RepositoryDetailViewModel` 调用 `GET /repos/{owner}/{repo}` 补全搜索列表中缺失的字段（尤其是 `open_issues_count` 与 `topics`）。有数据时展示 open issues 与 topics；提供 **「在 GitHub 中打开」** 在 `SFSafariViewController` 中打开 `html_url`。出错时尽量保留已缓存的行数据，而不是整页空白。

### P1.2 分页
`HomeViewModel` 与 `SearchViewModel` 均维护：

```swift
private(set) var currentPage: Int
private(set) var isLoadingNextPage: Bool
private(set) var hasMore: Bool
```

在 `tableView(_:willDisplay:forRowAt:)` 中当行索引位于最后 5 行内时调用 `loadNextPageIfNeeded()`。会过滤重复 ID。加载下一页时底部 `UIActivityIndicatorView` 作为 `tableFooterView` 显示；当返回条数少于 `pageSize` 时停止分页。

### P1.3 下拉刷新
首页与搜索均绑定 `UIRefreshControl`。下拉会重新加载第一页、清空累加器与分页状态；下一非 loading 状态到达后隐藏转圈。

### P1.4 单元测试（XCTest）
用聚焦的 XCTest 用例替换自动生成占位 —— 刻意保持精简，仅作 XCTest 示范：

- `EndpointTests` — 校验仓库搜索与详情等 endpoint 的路径、方法、查询参数。
- `GitHubRepositoryDecodingTests` — 用 `JSONDecoder` 往返示例 JSON（snake_case → camelCase、ISO-8601 日期、可选字段）。
- `SearchViewModelTests` — `loading → loaded` 成功路径、`loading → error` 失败路径、空查询重置，均由 mock `GitHubServiceProtocol` 驱动。
- `AuthServiceTests` — 有效已存 token 的 `restoreSession`、无 token、无效 token（抛 `.unauthorized`）、`logout` 清除会话但保留令牌、`revokeStoredLogin` 清除 Keychain 与内存用户等。
- `KeychainSecureStorageTests` — 针对真实 **KeychainAccess** 栈的 `save` / `read` / `delete` 与覆盖行为，每条测试使用独立 `service` id，避免与正式应用项冲突。
- `GitHubClientTests` — `AppError` 本地化文案冒烟。

Mock 位于 `GitHubClientTests/Mocks/TestMocks.swift`。可在 IDE（`⌘U`）或命令行运行：

```bash
xcodebuild -project GitHubClient.xcodeproj \
  -scheme GitHubClient \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:GitHubClientTests test
```

### P1.5 能力 / 权利
启用 **Keychain Sharing** 作为演示能力。权利文件为 `SupportingFiles/GitHubClient.entitlements`（在同步源码组外，以免被复制进 bundle），通过 `CODE_SIGN_ENTITLEMENTS` 关联。访问组为 `$(AppIdentifierPrefix)$(CFBundleIdentifier)`，即应用默认组，因此 `KeychainSecureStorage` **无需**在运行时设置 `kSecAttrAccessGroup`，行为与之前一致。

若更换开发团队导致自动签名不接受该权利，可从 `GitHubClient` 目标的 Debug/Release 配置中移除 `CODE_SIGN_ENTITLEMENTS` —— Keychain 仍可用，因为默认仍落在本应用访问组。按 `PROJECT_SPEC.md` §P1.5，签名问题不应阻塞项目。

### P1.6 自定义组件
新增 `StatBadgeView`（图标 + 数值胶囊），并重构 `RepositoryCardView` 用于列表中的星标与 Fork。可复用组件集合为：

```
AvatarImageView     （Kingfisher 加载远程图）
RepositoryCardView   （首页与搜索列表 cell 及详情头图使用）
StatBadgeView        （RepositoryCardView 与 RepositoryDetailViewController 使用）
ErrorStateView
EmptyStateView
LoadingView
```

## 已完成（P2）

UI 测试（XCUITest）

## 已知限制

- SnapKit / Kingfisher / KeychainAccess **仅在少数位置** 使用（登录布局、头像、令牌存储）；其余 UI 与网络仍为原生 UIKit + `URLSession`。
- **应用包内的 `clientSecret`** — 原生二进制无法真正保密 OAuth client secret。本项目按 `OAUTH_SPEC.md` 在设备上换 token；生产环境应通过后端代理该 POST（同 **登录方式** 中 **生产环境注意**）。
- 不包含 TestFlight 分发说明。使用有效 Apple Developer 账号可 archive 并上传。
- 本项目未使用 SwiftUI。
