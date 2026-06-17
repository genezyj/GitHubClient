//
//  OAuthConfig.swift
//  GitHubClient
//
//  Reviewer: create your own GitHub OAuth App
//  (https://github.com/settings/developers) and fill in the client ID /
//  client secret below. The redirect URI / callback scheme must match the
//  values you registered on GitHub AND the URL scheme registered in
//  `SupportingFiles/GitHubClient-Info.plist`.
//
//  Production note: a native iOS app cannot truly keep `clientSecret`
//  confidential. For a real app, move the token-exchange POST to a
//  backend (Cloudflare Worker, etc.). Inline secret use here is an
//  explicit demo compromise documented in README.
//

import Foundation

enum OAuthConfig {
    /// GitHub OAuth Client ID.
    static let clientID = "Ov23lihSDo8UMPRJVQRi"

    /// GitHub OAuth Client Secret.
    /// See file header for the production caveat.
    static let clientSecret = "128aa6464f81a7a61d90655534c163b4a0446f92"

    /// Must exactly match the Authorization callback URL registered on
    /// GitHub.
    static let redirectURI = "githubclient://oauth/callback"

    /// Scheme component of `redirectURI`, passed to
    /// `ASWebAuthenticationSession`.
    static let callbackScheme = "githubclient"

    /// Public profile + primary email + starring public repositories.
    static let scope = "read:user user:email public_repo"

    static let authorizeURL = URL(string: "https://github.com/login/oauth/authorize")!
    static let accessTokenURL = URL(string: "https://github.com/login/oauth/access_token")!

    /// `true` when either credential is still the Xcode placeholder. UI
    /// surfaces a helpful inline message instead of starting the flow.
    static var isPlaceholderCredentialed: Bool {
        return clientID.contains("#") || clientSecret.contains("#")
            || clientID.isEmpty || clientSecret.isEmpty
    }
}
