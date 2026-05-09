# GitHub iOS Native App — Cursor Agent Spec, OAuth Version

## 0. 核心修改

本版本将原先的 **Personal Access Token 手动输入登录** 改为真正面向用户的 **Sign in with GitHub / GitHub OAuth 登录**。

用户不需要去 GitHub 官网手动创建 token，也不需要复制粘贴 token。登录入口应该是：

```text
使用 GitHub 登录
```

点击后通过 `ASWebAuthenticationSession` 打开 GitHub 官方授权页面，用户完成登录和授权后，App 接收 OAuth callback，换取 access token，并将 token 安全存入 Keychain。

## 3. OAuth Login Design

### 3.1 Required Login Method

Use:

```text
Sign in with GitHub
```

Implementation flow:

```text
ASWebAuthenticationSession
→ GitHub OAuth authorize endpoint
→ callback URL returns temporary code
→ validate state
→ exchange code for OAuth access token
→ save token in Keychain
→ call GET /user
→ show authenticated Profile page
```

The previous manual token input screen is removed.

---

### 3.2 OAuth Flow Type

Use:

```text
OAuth Authorization Code Flow with PKCE
```

The app must generate and use:

- `state`
- `code_verifier`
- `code_challenge`
- `code_challenge_method=S256`

The app must validate returned `state` before exchanging the code for token.

---

### 3.3 GitHub OAuth App Configuration

Create a GitHub OAuth App in GitHub Developer Settings.

Recommended configuration:

```text
Application name:
GitHubClient iOS Demo

Homepage URL:
https://github.com

Authorization callback URL:
githubclient://oauth/callback
```

The iOS project must register the custom URL scheme in `Info.plist`:

```text
URL Scheme:
githubclient
```

The callback URL used in OAuth requests:

```text
githubclient://oauth/callback
```

---

### 3.4 OAuth Client Credentials

Create:

```swift
struct OAuthConfig {
    static let clientID = "<#GitHub OAuth Client ID#>"
    static let clientSecret = "<#GitHub OAuth Client Secret#>"
    static let redirectURI = "githubclient://oauth/callback"
    static let callbackScheme = "githubclient"
}
```

Do not commit real credentials into a public repository.

Recommended for this home task:

```text
OAuthConfig.swift or OAuthConfig.xcconfig uses placeholders.
README explains that reviewers should create their own GitHub OAuth App and fill in credentials locally.
```

Production security note:

```text
A native mobile app cannot truly keep a client secret confidential.
For a production app, move token exchange to a small backend / Cloudflare Worker.
For this home task, direct token exchange in the iOS app is acceptable only as a demo compromise, and this limitation must be documented in README.
```

---

### 3.5 OAuth Scopes

For P0, request minimal scopes:

```text
read:user user:email
```

Do not request `repo` in P0 unless private repositories are implemented.

Reason:

- Public repository search does not require login.
- Profile page only needs basic user identity.
- Minimal scope reduces security exposure and user friction.

---

### 3.6 Authorization URL

Build:

```text
https://github.com/login/oauth/authorize
```

Query parameters:

```text
client_id=<client_id>
redirect_uri=githubclient://oauth/callback
scope=read:user user:email
state=<random_state>
code_challenge=<base64url_sha256(code_verifier)>
code_challenge_method=S256
prompt=select_account
```

`prompt=select_account` helps testing because it makes account selection more explicit.

---

### 3.7 Callback Handling

Use:

```swift
ASWebAuthenticationSession(
    url: authorizationURL,
    callbackURLScheme: OAuthConfig.callbackScheme
) { callbackURL, error in
    // parse callback
}
```

Expected callback:

```text
githubclient://oauth/callback?code=...&state=...
```

Required behavior:

1. Extract `code`.
2. Extract `state`.
3. Verify callback `state` equals locally stored `state`.
4. If mismatch, abort with `.invalidOAuthState`.
5. Exchange code for access token.

The `ASWebAuthenticationSession` object must be retained while authentication is in progress.

---

### 3.8 Token Exchange

Call:

```text
POST https://github.com/login/oauth/access_token
```

Headers:

```text
Accept: application/json
Content-Type: application/x-www-form-urlencoded
```

Body:

```text
client_id=<client_id>
client_secret=<client_secret>
code=<authorization_code>
redirect_uri=githubclient://oauth/callback
code_verifier=<original_code_verifier>
```

Expected response:

```json
{
  "access_token": "gho_xxx",
  "scope": "read:user,user:email",
  "token_type": "bearer"
}
```

After receiving token:

1. Save `access_token` in Keychain.
2. Call `GET https://api.github.com/user`.
3. Update Profile page to logged-in state.

---

### 3.9 OAuth Error Handling

Handle:

- User cancels login.
- Missing callback URL.
- Missing authorization code.
- State mismatch.
- Token exchange failure.
- Invalid client credentials.
- Network failure.
- `/user` validation failure.

Recommended error cases:

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
    case oauthCancelled
    case invalidOAuthCallback
    case invalidOAuthState
    case tokenExchangeFailed
    case biometricUnavailable
    case biometricFailed
    case unknown
}
```

---

### 3.10 Logout Semantics

Logout should:

- Delete OAuth token from Keychain.
- Clear in-memory session.
- Return Profile page to guest state.
- Keep Home/Search accessible.

Important limitation:

```text
Logout does not necessarily clear the GitHub browser session used by ASWebAuthenticationSession.
If user signs in again, GitHub may reuse an existing browser session.
This is normal OAuth behavior.
```

---

```text
Tap 使用 GitHub 登录
→ Start ASWebAuthenticationSession
→ GitHub login/authorization page opens
→ User authorizes app
→ GitHub redirects to githubclient://oauth/callback
→ App receives code
→ App exchanges code for token
→ App saves token in Keychain
→ App fetches /user
→ Profile page updates to logged-in state
```

Do not implement manual PAT login.

Do not implement username/password login.

---

### P0.7 Logout

```text
Tap Logout
→ Show confirmation alert
→ If confirmed:
    delete token from Keychain
    clear session
    reset Profile page to guest state
    keep Home/Search accessible
```

---
--

### P0.8 Biometric Login / Local Unlock

Biometric login does not replace GitHub OAuth. It only unlocks a saved OAuth token.

```text
First OAuth login succeeds
→ Save token in Keychain

Later app launch or Profile guest state
→ If saved token exists and biometric is available:
    show 使用 Face ID / Touch ID 登录
→ On biometric success:
    read token from Keychain
    call GET /user
    restore logged-in state
→ On biometric failure:
    stay in guest state
```

Use:

```swift
LocalAuthentication
LAContext
evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: ...)
```

---

### P0.9 Secure Storage

Store OAuth token in Keychain.

Do not store token in:

- `UserDefaults`
- plist
- JSON file
- SQLite plain text
- Core Data plain text

Required protocol:

```swift
protocol SecureStorageProtocol {
    func saveToken(_ token: String) throws
    func readToken() throws -> String?
    func deleteToken() throws
}
```

Implementation:

```swift
final class KeychainSecureStorage: SecureStorageProtocol
```

Use KeychainAccess internally.

---
