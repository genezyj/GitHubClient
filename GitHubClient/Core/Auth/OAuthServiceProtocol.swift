//
//  OAuthServiceProtocol.swift
//  GitHubClient
//

import AuthenticationServices
import Foundation

@MainActor
protocol OAuthServiceProtocol: AnyObject {
    /// Run the full Authorization Code + PKCE flow against GitHub:
    /// open `ASWebAuthenticationSession`, validate state, exchange the
    /// code for an access token. Returns the OAuth bearer token.
    func authenticate(presentationAnchor: ASPresentationAnchor) async throws -> String
}
