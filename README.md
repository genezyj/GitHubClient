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
- Secure Keychain storage for that token
- Reusable avatar image component
- Unified loading / empty / error states
- Light & dark mode
- Simplified Chinese (`zh-Hans`) localization
- iPhone & iPad layout

## Tech Stack

- Swift, UIKit (programmatic Auto Layout via `NSLayoutConstraint`)
- MVVM + lightweight composition root (`AppCoordinator`)
- Native `URLSession` behind `APIClientProtocol`
- **AuthenticationServices** — `ASWebAuthenticationSession` for GitHub OAuth; **CryptoKit** for PKCE (`code_verifier` / S256 `code_challenge`)
- Native `Security` framework (`SecItem*`) behind `SecureStorageProtocol` (OAuth access token)
- `LocalAuthentication` (`LAContext`) for biometrics (unlocks saved token only)
- Custom URL scheme **`githubclient`** registered in `SupportingFiles/GitHubClient-Info.plist` for `githubclient://oauth/callback`
- `XCTest` (existing target — additional tests are P1, not yet added)

### Why no SnapKit / Kingfisher / KeychainAccess?

The spec recommends those three SPM packages. To avoid risk to the existing
`.xcodeproj` (and to keep the project free of network-dependent setup), this
P0 implementation uses native equivalents:

| Spec recommendation | What this project uses                                                                  |
| ------------------- | --------------------------------------------------------------------------------------- |
| SnapKit             | Programmatic `NSLayoutConstraint` and `UIStackView`                                     |
| Kingfisher          | A small `RemoteImageLoader` (`URLSession` + `NSCache`) hidden behind `AvatarImageView`  |
| KeychainAccess      | Direct `Security` framework calls inside `KeychainSecureStorage`                        |

The protocols (`SecureStorageProtocol`, etc.) are still in place, so swapping
in the third-party packages later is a one-file change.

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
 │    ├── Home/           — HomeViewController + HomeViewModel
 │    ├── Search/         — SearchViewController + SearchViewModel
 │    ├── Profile/        — ProfileViewController + ProfileViewModel
 │    └── Login/          — LoginViewController + LoginViewModel
 ├── UIComponents/        — AvatarImageView, RepositoryCardView, RepositoryListCell,
 │                          ErrorStateView, EmptyStateView, LoadingView, RemoteImageLoader
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
6. Save the access token in the iOS Keychain
   (`kSecClassGenericPassword`, `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`).
7. Validate the token with `GET /user` and update the Profile UI.

OAuth access-token handling:

- Sent as `Authorization: Bearer <token>` on authenticated requests.
- **Never** stored in `UserDefaults`, logged to the console, printed in
  headers, or hardcoded in source.
- Logout deletes the token from the Keychain and clears the in-memory
  session. As noted in `OAUTH_SPEC.md`, logout does **not** clear GitHub's
  own browser cookies — that's standard OAuth behavior for
  `ASWebAuthenticationSession`.

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

### Production caveat (documented per spec §3.4)

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
4. Tap `退出登录` to log out. Re-open Profile → `使用 Face ID / Touch ID 登录`
   to restore the logged-in state from the saved token without going
   through the OAuth flow again.

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
- All layouts use safe area + `UIStackView` + Auto Layout — no hardcoded
  screen widths.

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

## Known Limitations

- The three recommended SPM packages (SnapKit, Kingfisher, KeychainAccess)
  are intentionally swapped for native equivalents to keep the existing
  `.xcodeproj` un-touched in P0. See "Why no SnapKit…" above.
- **`clientSecret` in the app bundle** — a native binary cannot keep a OAuth
  client secret truly private. This project exchanges the authorization code
  on-device per `OAUTH_SPEC.md`; production builds should proxy that POST
  through a backend (same note under **Production caveat** in **Login Method**).
- Repository detail page, pagination, pull-to-refresh, mock mode, and
  expanded XCTest coverage are P1 in the original `PROJECT_SPEC.md` and **are not implemented** here.
- TestFlight distribution is not included. The app can be archived and
  uploaded with a valid Apple Developer account.

## Future Improvements (P1 / P2 from the spec)

- Repository detail page (`GET /repos/{owner}/{repo}`).
- Pagination on Home and Search.
- `UIRefreshControl` pull-to-refresh.
- XCTest unit tests: `EndpointTests`, `GitHubRepositoryDecodingTests`,
  `SearchViewModelTests`, `AuthServiceTests`.
- Mock mode behind `-useMockData` launch argument.
- `RepositoryCardView` already exists; can promote `StatBadgeView` and other
  small components.
- XCUITest UI tests on top of mock mode.
- Backend proxy for OAuth token exchange (hide `clientSecret` from clients).
- Optional offline cache of last-loaded results.
