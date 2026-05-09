//
//  OAuthService.swift
//  GitHubClient
//
//  GitHub OAuth (Authorization Code + PKCE) using `ASWebAuthenticationSession`.
//

import AuthenticationServices
import Foundation

@MainActor
final class OAuthService: NSObject, OAuthServiceProtocol {

    private let urlSession: URLSession
    private let decoder: JSONDecoder

    /// Strong reference for the duration of the web auth flow. Apple's API
    /// requires the caller to retain the session until the completion
    /// handler fires.
    private var currentWebAuthSession: ASWebAuthenticationSession?

    /// Anchor passed by the screen presenting OAuth. Stored so the
    /// presentationContextProvider callback can return it.
    private weak var currentPresentationAnchor: ASPresentationAnchor?

    init(
        urlSession: URLSession = .shared,
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.urlSession = urlSession
        self.decoder = decoder
        super.init()
    }

    // MARK: OAuthServiceProtocol

    func authenticate(presentationAnchor: ASPresentationAnchor) async throws -> String {
        guard !OAuthConfig.isPlaceholderCredentialed else {
            throw AppError.tokenExchangeFailed
        }

        let pkce = PKCE.generate()
        let state = PKCE.generateState()
        let authorizationURL = try buildAuthorizationURL(state: state, codeChallenge: pkce.challenge)

        let callbackURL = try await startWebAuthSession(
            url: authorizationURL,
            presentationAnchor: presentationAnchor
        )

        let (code, returnedState) = try parseCallback(callbackURL)
        guard returnedState == state else {
            throw AppError.invalidOAuthState
        }

        return try await exchangeCodeForToken(code: code, codeVerifier: pkce.verifier)
    }

    // MARK: Authorization URL

    private func buildAuthorizationURL(state: String, codeChallenge: String) throws -> URL {
        guard var components = URLComponents(url: OAuthConfig.authorizeURL, resolvingAgainstBaseURL: false) else {
            throw AppError.invalidURL
        }
        components.queryItems = [
            URLQueryItem(name: "client_id", value: OAuthConfig.clientID),
            URLQueryItem(name: "redirect_uri", value: OAuthConfig.redirectURI),
            URLQueryItem(name: "scope", value: OAuthConfig.scope),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "prompt", value: "select_account")
        ]
        guard let url = components.url else { throw AppError.invalidURL }
        return url
    }

    // MARK: Web auth session

    private func startWebAuthSession(
        url: URL,
        presentationAnchor: ASPresentationAnchor
    ) async throws -> URL {
        currentPresentationAnchor = presentationAnchor

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: OAuthConfig.callbackScheme
            ) { [weak self] callbackURL, error in
                self?.currentWebAuthSession = nil
                self?.currentPresentationAnchor = nil

                if let error = error as NSError? {
                    if error.domain == ASWebAuthenticationSessionError.errorDomain,
                       error.code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        continuation.resume(throwing: AppError.oauthCancelled)
                    } else {
                        continuation.resume(throwing: AppError.network(error.localizedDescription))
                    }
                    return
                }
                guard let callbackURL else {
                    continuation.resume(throwing: AppError.invalidOAuthCallback)
                    return
                }
                continuation.resume(returning: callbackURL)
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            currentWebAuthSession = session

            if !session.start() {
                currentWebAuthSession = nil
                currentPresentationAnchor = nil
                continuation.resume(throwing: AppError.unknown)
            }
        }
    }

    private func parseCallback(_ url: URL) throws -> (code: String, state: String) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw AppError.invalidOAuthCallback
        }
        // Surface GitHub-side errors first (e.g. user denies on the consent screen).
        if let errorParam = components.queryItems?.first(where: { $0.name == "error" })?.value {
            if errorParam == "access_denied" {
                throw AppError.oauthCancelled
            }
            throw AppError.tokenExchangeFailed
        }
        guard
            let code = components.queryItems?.first(where: { $0.name == "code" })?.value, !code.isEmpty,
            let state = components.queryItems?.first(where: { $0.name == "state" })?.value, !state.isEmpty
        else {
            throw AppError.invalidOAuthCallback
        }
        return (code, state)
    }

    // MARK: Token exchange

    private func exchangeCodeForToken(code: String, codeVerifier: String) async throws -> String {
        var request = URLRequest(url: OAuthConfig.accessTokenURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyItems: [(String, String)] = [
            ("client_id", OAuthConfig.clientID),
            ("client_secret", OAuthConfig.clientSecret),
            ("code", code),
            ("redirect_uri", OAuthConfig.redirectURI),
            ("code_verifier", codeVerifier)
        ]
        request.httpBody = formURLEncode(bodyItems).data(using: .utf8)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            throw AppError.network(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw AppError.tokenExchangeFailed
        }
        do {
            let payload = try decoder.decode(TokenResponse.self, from: data)
            // GitHub returns 200 + an `error` field on failed exchanges.
            if let access = payload.accessToken, !access.isEmpty {
                return access
            }
            throw AppError.tokenExchangeFailed
        } catch let appError as AppError {
            throw appError
        } catch {
            throw AppError.tokenExchangeFailed
        }
    }

    private func formURLEncode(_ items: [(String, String)]) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        // Keep encoding strict for body values: drop sub-delim chars that
        // can break some servers (`+`, `&`, `=`, etc.).
        allowed.remove(charactersIn: "+&=?#")
        return items.map { key, value in
            let encodedKey = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
            let encodedValue = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
            return "\(encodedKey)=\(encodedValue)"
        }.joined(separator: "&")
    }

    private struct TokenResponse: Decodable {
        let accessToken: String?
        let scope: String?
        let tokenType: String?
        let error: String?
        let errorDescription: String?

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case scope
            case tokenType = "token_type"
            case error
            case errorDescription = "error_description"
        }
    }
}

extension OAuthService: ASWebAuthenticationPresentationContextProviding {
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // Apple calls this on the main thread; bounce to the main actor to
        // satisfy isolation while reading our stored anchor.
        return MainActor.assumeIsolated {
            currentPresentationAnchor ?? ASPresentationAnchor()
        }
    }
}
