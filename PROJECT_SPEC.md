# GitHub iOS Native App — Cursor Agent Project Spec

> Purpose: This document is designed as a direct input for Cursor Agent Mode. Cursor should use it to generate the iOS project structure, core architecture, reusable components, and features in priority order.

---

## 0. Recommended Document Format

Use this **Markdown document** as the Cursor input.

Markdown is preferred over PDF because:

- Cursor can read and reason over Markdown more reliably than PDF.
- Code blocks, folder structures, priority labels, and implementation steps remain machine-readable.
- The document can be edited iteratively during development.
- It can live directly in the project repository as `PROJECT_SPEC.md` or `README_DEV.md`.

Do not use PDF as the primary input for Cursor. PDF is better for human review, not agent-driven code generation.

---

## 1. Project Overview

Build a native iOS GitHub client app using **Swift + UIKit**.

The app should support:

- Guest browsing without login.
- Home page showing popular Swift repositories.
- Repository search.
- Profile page with guest and logged-in states.
- Token-based GitHub login.
- Logout.
- Face ID / Touch ID local unlock after successful login.
- Secure token storage using Keychain.
- Reusable remote avatar/image component.
- Unified loading, empty, and error states.
- Light and dark mode.
- Simplified Chinese localization through localization files.
- Basic iPhone and iPad adaptation.
- XCTest unit tests if time allows.

This is a home task project. Prioritize a small, complete, clean, and explainable implementation over excessive feature scope.

---

## 2. Priority System

Use three priority levels.

### P0 — Must Have

Required for the assignment to be considered complete.

### P1 — Strong Plus

Important engineering or product improvements. Implement after P0, or implement together with P0 if the cost is low.

### P2 — Optional Enhancement

Useful later-stage improvements. Do not start P2 before P0 is stable.

---

## 3. Core Technical Decisions

| Area | Decision |
|---|---|
| Language | Swift |
| Minimum iOS Version | iOS 14.0 |
| UI Framework | UIKit |
| Layout | Programmatic UIKit + SnapKit |
| Architecture | MVVM + light Coordinator / navigation setup + protocol-oriented services |
| Dependency Manager | Swift Package Manager |
| Networking | Native `URLSession` wrapped behind `APIClientProtocol` |
| Image Loading | Kingfisher |
| Secure Storage | KeychainAccess |
| Biometric Auth | Apple `LocalAuthentication` |
| Tests | XCTest; XCUITest optional |
| Resources | `Assets.xcassets` |
| Localization | `zh-Hans.lproj/Localizable.strings` |
| Theme | System dynamic colors + Asset Catalog named colors where needed |

### Third-Party Libraries

Use only these libraries unless absolutely necessary:

1. **SnapKit**
   - Purpose: programmatic Auto Layout.
   - Use in UIKit views and view controllers.
   - Avoid Storyboard.

2. **Kingfisher**
   - Purpose: remote avatar image loading and caching.
   - Use only inside reusable image components such as `AvatarImageView`.
   - Avoid scattering Kingfisher calls across feature view controllers.

3. **KeychainAccess**
   - Purpose: secure token storage.
   - Do not store tokens in `UserDefaults`.

Do **not** use Alamofire in this project. Native `URLSession` is enough and demonstrates better control over request construction, response handling, and protocol abstraction.

---

## 4. Explicit Security and Authentication Decisions

Do **not** implement GitHub username/password login.

Correct authentication approach for this home task:

```text
User manually enters GitHub Personal Access Token
→ App validates token by calling GET /user
→ If valid, app stores token in Keychain
→ App uses token in Authorization header for authenticated requests
```

Correct biometric interpretation:

```text
GitHub token login = remote authentication
Face ID / Touch ID = local unlock for previously saved token
```

Biometric login must not be treated as GitHub authentication by itself.

Use:

```swift
import LocalAuthentication
```

Use `LAContext` to evaluate biometric authentication.

---

## 5. P0 Product Requirements

### P0.1 App Structure

Create a UIKit app with this navigation structure:

```text
App Launch
  → MainTabBarController
      → Home
      → Search
      → Profile
```

Each tab should be embedded in a `UINavigationController`.

Required tabs:

1. Home
2. Search
3. Profile

Login must not block app entry. Guest users should be able to open the app and browse Home/Search.

---

### P0.2 Guest Mode

The app must work without login.

Guest users can:

- View Home page.
- Search public repositories.
- View basic public repository information.
- Open Profile tab and see login entry points.

Guest users cannot:

- View authenticated private information.
- Access private repositories.
- Perform authenticated GitHub actions.

---

### P0.3 Home Page

Home page should show public GitHub repositories.

Use this content strategy:

```text
Popular Swift Repositories
```

Recommended API:

```text
GET /search/repositories?q=language:swift stars:>5000&sort=stars&order=desc&per_page=20
```

UI should display each repository with:

- Repository name
- Owner username
- Owner avatar
- Description
- Primary language
- Star count
- Fork count
- Updated date if available

Required states:

- Loading
- Loaded
- Empty
- Error with retry

---

### P0.4 Search Page

Search page should allow users to search GitHub repositories.

Use either:

- `UISearchController`, preferred; or
- a custom `UITextField` search bar if simpler.

Minimum behavior:

```text
User enters keyword
→ taps Search on keyboard
→ app calls GitHub repository search API
→ results displayed in list
```

Recommended API:

```text
GET /search/repositories?q={query}&sort=stars&order=desc&per_page=20
```

Search result cell should reuse the same repository display component as Home.

Required states:

- Initial empty state: “请输入关键词搜索仓库”
- Loading
- Results
- No results
- Error with retry

Do not implement user search in P0. Repository search is enough.

---

### P0.5 Profile Page

Profile page has two states.

#### Guest State

Show:

- Placeholder avatar
- Text: “未登录”
- Button: “使用 Token 登录”
- Button: “使用 Face ID / Touch ID 登录”, only if saved token and biometric support exist
- Optional explanation: “登录后可查看你的 GitHub 个人资料”

#### Logged-In State

After login, show authenticated user information:

- Avatar
- Username
- Display name
- Bio
- Public repos count
- Followers count
- Following count
- Location if available
- Blog link if available
- Logout button

Authenticated profile should be fetched from:

```text
GET /user
```

---

### P0.6 Login

Implement token-based login.

Login flow:

```text
Profile tab
  → Tap “使用 Token 登录”
  → LoginViewController
      → Token input field
      → Login button
  → Validate token by calling GET /user
  → If success:
        save token to Keychain
        save basic user session in memory
        update Profile tab
  → If failure:
        show common error state or inline error message
```

Rules:

- Do not ask for GitHub password.
- Do not store token in `UserDefaults`.
- Do not log token to console.
- Do not hardcode token in source code.
- Use `Authorization: Bearer <token>` header when token exists.

Token field behavior:

- Secure text entry.
- Disable autocorrection.
- Disable autocapitalization.
- Trim whitespace before validation.

---

### P0.7 Logout

User must be able to log out.

Logout behavior:

```text
Tap Logout
→ Show confirmation alert
→ If confirmed:
    delete token from Keychain
    clear in-memory session
    reset Profile page to guest state
    keep Home/Search accessible
```

Logout must not make the app unusable. It should return the app to guest mode.

---

### P0.8 Biometric Login / Local Unlock

Implement Face ID / Touch ID local unlock after first successful token login.

Behavior:

```text
First successful token login
→ Save token in Keychain
→ Biometric login becomes available if device supports it

Next app launch or Profile guest state
→ If saved token exists:
    show “使用 Face ID / Touch ID 登录”
→ On biometric success:
    read token from Keychain
    call GET /user
    restore logged-in state
→ On biometric failure:
    remain in guest state
```

Use:

```swift
LocalAuthentication
LAContext
context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: ...)
```

Fallback rules:

- If biometric is unavailable, hide biometric login button.
- Manual token login should still work.

---

### P0.9 Image Widget

Implement one reusable image component.

Required component:

```text
AvatarImageView
```

Responsibilities:

- Display remote avatar URL.
- Show placeholder image while loading.
- Show fallback placeholder on failure.
- Support circular style.
- Support reuse in table/collection cells.
- Use Kingfisher internally.
- Avoid exposing Kingfisher calls throughout business UI.

Suggested API:

```swift
final class AvatarImageView: UIView {
    func configure(url: URL?, size: CGFloat)
    func reset()
}
```

Use this component in:

- Home repository list
- Search repository list
- Profile page

---

### P0.10 Common Error Page / Error State

Implement a reusable error view.

Required component:

```text
ErrorStateView
```

Should display:

- Icon or system image
- Title
- Message
- Retry button

Suggested API:

```swift
final class ErrorStateView: UIView {
    var onRetry: (() -> Void)?
    func configure(title: String, message: String, retryTitle: String)
}
```

Use it for:

- Home API failure
- Search API failure
- Profile fetch failure
- Login token validation failure where appropriate

Also implement `EmptyStateView` if low cost, but `ErrorStateView` is P0.

---

### P0.11 Unified View State

Each major ViewModel should expose a state.

Use:

```swift
enum ViewState<Value> {
    case idle
    case loading
    case loaded(Value)
    case empty
    case error(AppError)
}
```

Use this in:

- `HomeViewModel`
- `SearchViewModel`
- `ProfileViewModel`
- `LoginViewModel`

Do not put networking logic directly inside ViewControllers.

---

### P0.12 Localization

Even though only simplified Chinese is required, all user-facing text should come from localization files.

Use:

```text
zh-Hans.lproj/Localizable.strings
```

Required keys:

```text
"tab.home" = "首页";
"tab.search" = "搜索";
"tab.profile" = "我的";

"home.title" = "热门 Swift 仓库";
"search.title" = "搜索";
"search.placeholder" = "搜索 GitHub 仓库";
"search.initial_empty" = "请输入关键词搜索仓库";
"search.no_results" = "没有找到相关仓库";

"profile.not_logged_in" = "未登录";
"profile.login_with_token" = "使用 Token 登录";
"profile.login_with_biometrics" = "使用 Face ID / Touch ID 登录";
"profile.logout" = "退出登录";
"profile.logout_confirm_title" = "确认退出登录？";
"profile.logout_confirm_message" = "退出后仍可继续浏览公开内容。";

"login.title" = "登录 GitHub";
"login.token_placeholder" = "请输入 GitHub Personal Access Token";
"login.button" = "登录";
"login.note" = "App 不会保存你的 GitHub 密码，Token 会安全存储在系统 Keychain 中。";

"common.cancel" = "取消";
"common.confirm" = "确认";

"error.title" = "出现问题";
"error.network" = "网络连接失败，请稍后重试";
"error.unauthorized" = "登录凭证无效，请重新登录";
"error.rate_limit" = "请求过于频繁，请稍后再试";
"error.not_found" = "未找到相关内容";
"error.server" = "服务器暂时不可用，请稍后再试";
"error.unknown" = "发生未知错误";
"error.retry" = "重试";
```

Use a wrapper:

```swift
enum L10n {
    static let homeTab = NSLocalizedString("tab.home", comment: "")
    static let searchTab = NSLocalizedString("tab.search", comment: "")
    static let profileTab = NSLocalizedString("tab.profile", comment: "")
}
```

Do not hardcode visible Chinese strings directly in view controllers.

---

### P0.13 Light and Dark Mode

Support light and dark mode.

Rules:

- Do not hardcode `.white` and `.black` unless intentional.
- Prefer system colors:
  - `.systemBackground`
  - `.secondarySystemBackground`
  - `.label`
  - `.secondaryLabel`
  - `.tertiaryLabel`
  - `.systemBlue`
  - `.separator`
- Use Asset Catalog named colors if custom colors are needed.
- Test Login, Home, Search, Profile, ErrorState in both modes.

---

### P0.14 Screen Size Support

Support major iPhone and iPad screen sizes.

Minimum requirement:

- Works on small iPhone.
- Works on large iPhone.
- Works on iPad.
- No broken layout in portrait.
- Landscape should not crash or produce unusable layout.

Implementation rules:

- Use Auto Layout via SnapKit.
- Respect safe area.
- Avoid fixed screen widths.
- For iPad, constrain content max width where needed.

Example:

```text
On iPad profile page, center content with max width around 600–700pt.
Repository lists can remain full-width but cells should have reasonable margins.
```

---

### P0.15 Assets

Use `Assets.xcassets` for:

- App icon placeholder
- Avatar placeholder
- Error state image if using image
- Empty state image if using image
- Named colors if needed

Do not place loose images randomly in the project root.

---

### P0.16 README

Create a clear `README.md`.

Must include:

- Project overview
- Tech stack
- Architecture
- How to run
- How to login using GitHub Personal Access Token
- Why username/password login is not implemented
- What features are completed
- What features are future improvements
- Known limitations

---

## 6. P1 Requirements

### P1.1 Repository Detail Page

Add a repository detail page.

Entry:

```text
Tap repository cell
→ RepositoryDetailViewController
```

Display:

- Repo full name
- Owner avatar and username
- Description
- Stars
- Forks
- Open issues
- Language
- Topics if available
- GitHub web URL
- Created / updated date

Recommended API:

```text
GET /repos/{owner}/{repo}
```

---

### P1.2 Pagination

Implement pagination for Home and Search.

Minimum behavior:

- Load first page.
- When user scrolls near bottom, load next page.
- Avoid duplicate loading.
- Show bottom loading indicator.
- Handle end of data.

ViewModel should track:

```swift
var currentPage: Int
var isLoadingNextPage: Bool
var hasMore: Bool
```

---

### P1.3 Pull to Refresh

Add `UIRefreshControl` to Home and Search.

Behavior:

```text
Pull down
→ reload first page
→ clear old pagination state
```

---

### P1.4 Unit Tests

Add XCTest unit tests.

Minimum tests:

1. `EndpointTests`
   - Verify path and query items for repository search.

2. `GitHubRepositoryDecodingTests`
   - Decode sample JSON into model.

3. `SearchViewModelTests`
   - Success state: loading → loaded.
   - Failure state: loading → error.

4. `AuthServiceTests`
   - Successful token validation.
   - Invalid token error.

Use mock services. Do not call real GitHub API in tests.

---

### P1.5 Capability / Entitlement

The assignment asks for at least one entitlement/capability.

Preferred approach:

- Add **Keychain Sharing** capability only if it does not create signing/build problems.
- Keep Keychain usage local to the app.
- Explain in README that Keychain is used for secure token storage, and Keychain Sharing is included only to demonstrate entitlement configuration.

Do not enable irrelevant capabilities such as Push Notifications or Background Modes unless actually used.

If enabling Keychain Sharing causes signing problems, do not block the project. Instead, document the decision in README.

---

### P1.6 Better Custom Components

In addition to `AvatarImageView`, add:

```text
RepositoryCardView
ErrorStateView
EmptyStateView
StatBadgeView
```

`RepositoryCardView` should be reusable by both Home and Search cells.

---

### P1.7 Mock Mode

Add mock mode for easier UI development and tests.

Use launch argument:

```text
-useMockData
```

Behavior:

- If launch argument exists, use `MockGitHubService`.
- Otherwise use real `GitHubService`.

This also makes UI tests easier later.

---

## 7. P2 Requirements

### P2.1 UI Tests

Add XCUITest for:

1. Launch app without login → Home visible.
2. Search “swift” → results visible.
3. Profile guest state → login button visible.
4. Mock login → profile visible.
5. Logout → profile returns to guest state.

Use accessibility identifiers only for UI testing. Full accessibility support is not required.

---

### P2.2 GitHub OAuth

Implement real GitHub OAuth using:

```text
ASWebAuthenticationSession
```

This is more production-like but not required for the home task because it requires GitHub OAuth App setup, callback URL scheme, and client configuration.

Do not implement OAuth before P0/P1 are stable.

---

### P2.3 SwiftUI Plus

Add one small SwiftUI component embedded in UIKit using `UIHostingController`.

Possible component:

```text
ProfileStatsSwiftUIView
```

Use this only as a plus. Main app must remain UIKit.

---

### P2.4 TestFlight

Publishing to TestFlight is optional.

If not done, README should state:

```text
TestFlight distribution is not included because this task is submitted as source code. The app can be archived and uploaded with a valid Apple Developer account.
```

---

### P2.5 Offline Cache

Optional:

- Cache last loaded Home/Search results.
- Use file cache or lightweight local persistence.
- Do not introduce Core Data unless necessary.

---

## 8. Architecture

Use MVVM with protocol-oriented services.

### High-Level Layers

```text
App
 ├── Coordinator / Navigation setup
 ├── Features
 │    ├── Home
 │    ├── Search
 │    ├── Profile
 │    ├── Login
 │    └── RepositoryDetail
 ├── Core
 │    ├── Networking
 │    ├── Services
 │    ├── Storage
 │    ├── Authentication
 │    ├── Models
 │    ├── Errors
 │    └── Utilities
 ├── UIComponents
 └── Resources
```

### Recommended Folder Structure

```text
GitHubClient/
  App/
    AppDelegate.swift
    SceneDelegate.swift
    AppCoordinator.swift
    MainTabBarController.swift

  Core/
    Networking/
      APIClient.swift
      APIClientProtocol.swift
      Endpoint.swift
      HTTPMethod.swift
      APIError.swift

    Services/
      GitHubService.swift
      GitHubServiceProtocol.swift
      MockGitHubService.swift

    Auth/
      AuthService.swift
      AuthServiceProtocol.swift
      BiometricAuthService.swift
      BiometricAuthProtocol.swift
      AuthSession.swift

    Storage/
      SecureStorage.swift
      SecureStorageProtocol.swift
      KeychainSecureStorage.swift

    Models/
      GitHubUser.swift
      GitHubRepository.swift
      RepositoryOwner.swift
      SearchRepositoriesResponse.swift

    State/
      ViewState.swift

    Utilities/
      DateFormatter+GitHub.swift
      NumberFormatter+Compact.swift
      L10n.swift

  Features/
    Home/
      HomeViewController.swift
      HomeViewModel.swift
      HomeRepositoryCell.swift

    Search/
      SearchViewController.swift
      SearchViewModel.swift

    Profile/
      ProfileViewController.swift
      ProfileViewModel.swift

    Login/
      LoginViewController.swift
      LoginViewModel.swift

    RepositoryDetail/
      RepositoryDetailViewController.swift
      RepositoryDetailViewModel.swift

  UIComponents/
    AvatarImageView.swift
    RepositoryCardView.swift
    ErrorStateView.swift
    EmptyStateView.swift
    StatBadgeView.swift
    LoadingView.swift

  Resources/
    Assets.xcassets
    zh-Hans.lproj/
      Localizable.strings

  Tests/
    GitHubClientTests/
    GitHubClientUITests/
```

---

## 9. Protocol-Oriented Design

Use protocols for all external dependencies.

### Required Protocols

```swift
protocol APIClientProtocol {
    func request<T: Decodable>(_ endpoint: Endpoint, token: String?) async throws -> T
}
```

```swift
protocol GitHubServiceProtocol {
    func fetchPopularSwiftRepositories(page: Int) async throws -> [GitHubRepository]
    func searchRepositories(query: String, page: Int) async throws -> [GitHubRepository]
    func fetchAuthenticatedUser(token: String) async throws -> GitHubUser
    func fetchRepository(owner: String, repo: String) async throws -> GitHubRepository
}
```

```swift
protocol SecureStorageProtocol {
    func saveToken(_ token: String) throws
    func readToken() throws -> String?
    func deleteToken() throws
}
```

```swift
protocol AuthServiceProtocol {
    var isLoggedIn: Bool { get }
    func login(token: String) async throws -> GitHubUser
    func restoreSession() async throws -> GitHubUser?
    func logout() throws
}
```

```swift
protocol BiometricAuthProtocol {
    func canEvaluateBiometrics() -> Bool
    func authenticate(reason: String) async throws -> Bool
}
```

Benefits:

- ViewModels are testable.
- Mock services can be injected.
- Networking is not coupled to UI.
- Keychain implementation can be replaced.
- Biometric logic is isolated.

---

## 10. Data Models

### GitHubUser

```swift
struct GitHubUser: Decodable {
    let id: Int
    let login: String
    let avatarUrl: URL?
    let htmlUrl: URL?
    let name: String?
    let company: String?
    let blog: String?
    let location: String?
    let email: String?
    let bio: String?
    let publicRepos: Int
    let followers: Int
    let following: Int
}
```

Use `CodingKeys` for snake_case mapping.

### RepositoryOwner

```swift
struct RepositoryOwner: Decodable, Hashable {
    let id: Int
    let login: String
    let avatarUrl: URL?
    let htmlUrl: URL?
}
```

### GitHubRepository

```swift
struct GitHubRepository: Decodable, Hashable {
    let id: Int
    let name: String
    let fullName: String
    let owner: RepositoryOwner
    let htmlUrl: URL?
    let description: String?
    let language: String?
    let stargazersCount: Int
    let forksCount: Int
    let openIssuesCount: Int?
    let topics: [String]?
    let createdAt: Date?
    let updatedAt: Date?
}
```

### SearchRepositoriesResponse

```swift
struct SearchRepositoriesResponse: Decodable {
    let totalCount: Int
    let incompleteResults: Bool
    let items: [GitHubRepository]
}
```

---

## 11. Networking Design

### Endpoint

Create an `Endpoint` type:

```swift
struct Endpoint {
    let path: String
    let method: HTTPMethod
    let queryItems: [URLQueryItem]
}
```

Example endpoints:

```swift
extension Endpoint {
    static func popularSwiftRepositories(page: Int) -> Endpoint
    static func searchRepositories(query: String, page: Int) -> Endpoint
    static var authenticatedUser: Endpoint
    static func repository(owner: String, repo: String) -> Endpoint
}
```

### Base URL

Use:

```text
https://api.github.com
```

### Headers

Every request should include:

```text
Accept: application/vnd.github+json
X-GitHub-Api-Version: 2026-03-10
```

If token exists:

```text
Authorization: Bearer <token>
```

### Error Mapping

Create:

```swift
enum AppError: Error {
    case invalidURL
    case network(Error)
    case decoding(Error)
    case unauthorized
    case forbidden
    case notFound
    case rateLimited
    case serverError
    case unknown
}
```

Map status codes:

```text
401 → unauthorized
403 → forbidden or rateLimited
404 → notFound
500...599 → serverError
```

UI should never display raw technical errors directly. Convert them to localized user-facing messages.

---

## 12. ViewModel Rules

ViewControllers should only handle:

- View setup
- Binding state
- User interaction forwarding
- Navigation trigger

ViewModels handle:

- Calling services
- State transitions
- Lightweight data formatting
- Error mapping

Example:

```swift
@MainActor
final class SearchViewModel {
    private let service: GitHubServiceProtocol

    private(set) var state: ViewState<[GitHubRepository]> = .idle {
        didSet { onStateChange?(state) }
    }

    var onStateChange: ((ViewState<[GitHubRepository]>) -> Void)?

    init(service: GitHubServiceProtocol) {
        self.service = service
    }

    func search(query: String) async {
        // validate query
        // set loading
        // call service
        // set loaded / empty / error
    }
}
```

---

## 13. UI Requirements

### General UI Rules

- Use UIKit programmatically.
- No Storyboard.
- Use SnapKit constraints.
- Use system fonts.
- Use native navigation bars and tab bars.
- Use `UITableView` or `UICollectionView`.
- Use `UIActivityIndicatorView` for loading.
- Use `UIAlertController` for logout confirmation.
- Use safe area constraints.

### Home UI

```text
Navigation title: 热门 Swift 仓库
List of repository cards
```

### Search UI

```text
Navigation title: 搜索
Search bar at top
Initial empty state
Results list
```

### Profile UI

Guest:

```text
Avatar placeholder
未登录
使用 Token 登录
使用 Face ID / Touch ID 登录, only if available
```

Logged in:

```text
Avatar
Name
Username
Bio
Stats row: Repos / Followers / Following
Logout button
```

### Login UI

```text
Navigation title: 登录 GitHub
Token text field
Login button
Explanatory note:
“请输入 GitHub Personal Access Token。App 不会保存你的 GitHub 密码，Token 会存储在系统 Keychain 中。”
```

---

## 14. Security Requirements

Do:

- Store token in Keychain.
- Delete token on logout.
- Avoid logging token.
- Avoid storing password.
- Avoid hardcoding credentials.
- Use biometric auth only to unlock stored token.
- Keep token storage behind `SecureStorageProtocol`.

Do not:

- Store token in `UserDefaults`.
- Store GitHub password.
- Put token in README.
- Print request headers with token.
- Commit test token.

---

## 15. Testing Requirements

### P1 Unit Tests

Use XCTest.

Required tests:

```text
EndpointTests
GitHubRepositoryDecodingTests
SearchViewModelTests
AuthServiceTests
```

Use mock JSON fixtures.

Do not test real network calls.

### P2 UI Tests

Use XCUITest only after P0/P1 are stable.

Use launch argument:

```text
-useMockData
```

Add accessibility identifiers only where needed for tests.

---

## 16. Implementation Order for Cursor

Cursor should implement in this exact order.

### Phase 1 — Project Setup

1. Create UIKit iOS app.
2. Set deployment target to iOS 14.0.
3. Add SPM dependencies:
   - SnapKit
   - Kingfisher
   - KeychainAccess
4. Create folder structure.
5. Add `Assets.xcassets`.
6. Add `zh-Hans.lproj/Localizable.strings`.

### Phase 2 — Core Infrastructure

1. Create models.
2. Create `Endpoint`.
3. Create `APIClientProtocol`.
4. Create `APIClient`.
5. Create `AppError`.
6. Create `ViewState`.
7. Create `GitHubServiceProtocol`.
8. Create `GitHubService`.

### Phase 3 — Main UI

1. Create `MainTabBarController`.
2. Create Home tab.
3. Create Search tab.
4. Create Profile tab.
5. Add basic navigation.

### Phase 4 — Components

1. Create `AvatarImageView`.
2. Create `RepositoryCardView`.
3. Create repository list cell.
4. Create `ErrorStateView`.
5. Create loading/empty handling.

### Phase 5 — Authentication

1. Create `SecureStorageProtocol`.
2. Create `KeychainSecureStorage`.
3. Create `AuthService`.
4. Create Login screen.
5. Implement token validation with `/user`.
6. Implement logout.
7. Implement biometric unlock.

### Phase 6 — Polish

1. Add localization for all strings.
2. Verify dark mode.
3. Verify iPad layout.
4. Add README.
5. Add unit tests.

### Phase 7 — Optional

1. Repository detail page.
2. Pagination.
3. Pull-to-refresh.
4. UI tests.
5. OAuth.
6. TestFlight.

---

## 17. Acceptance Criteria

The project is acceptable when:

- App builds successfully.
- App runs on iOS 14+ simulator.
- App launches directly into main tab UI without requiring login.
- Home page loads public repositories.
- Search page can search repositories.
- Profile page supports guest and logged-in states.
- Token login validates via GitHub API.
- Token is stored in Keychain.
- Logout clears session and returns to guest state.
- Biometric login works after a successful login if device supports it.
- Remote avatars load through reusable image component.
- Common error state is used for API failures.
- UI supports light and dark mode.
- UI does not break on iPhone and iPad.
- Strings are loaded from localization files.
- README explains setup, architecture, login method, and limitations.

---

## 18. Explicit Non-Goals

Do not implement these in P0:

- GitHub username/password login.
- Full GitHub OAuth.
- Private repository browsing.
- Star/unstar repository.
- Follow/unfollow user.
- Push notifications.
- Background modes.
- Full accessibility support.
- Full offline cache.
- TestFlight publishing.
- Complex dependency injection framework.
- Core Data.

These can be discussed as future improvements.

---

## 19. README Template

Cursor should create `README.md` with this structure:

```text
# GitHubClient iOS

## Overview
A native iOS GitHub client built with Swift and UIKit.

## Features
- Guest browsing
- Popular Swift repositories
- Repository search
- Token-based login
- Authenticated profile
- Logout
- Face ID / Touch ID local unlock
- Secure Keychain token storage
- Reusable avatar image component
- Unified error state
- Light/Dark mode
- zh-Hans localization

## Tech Stack
- Swift
- UIKit
- MVVM
- URLSession
- SnapKit
- Kingfisher
- KeychainAccess
- LocalAuthentication
- XCTest

## Architecture
Explain MVVM + protocol-oriented services.

## Login Method
This demo uses GitHub Personal Access Token login.
GitHub username/password login is intentionally not implemented because GitHub REST API does not support username/password authentication.

## How to Run
1. Open project in Xcode.
2. Resolve SPM dependencies.
3. Run on iOS 14+ simulator.

## Known Limitations
- OAuth is not included in P0.
- TestFlight is not included.
- Repository detail and pagination are optional enhancements if implemented.

## Future Improvements
- GitHub OAuth with ASWebAuthenticationSession
- Repository detail
- Pagination
- Pull to refresh
- UI tests
- Offline cache
```

---

## 20. Final Instruction to Cursor Agent

Implement the project incrementally.

First complete all P0 requirements and make sure the app compiles and runs. Then implement P1 items only if P0 is stable. Do not start P2 features until the core app is complete.

Prioritize correctness, clean architecture, secure token storage, and a working user flow over excessive features.
