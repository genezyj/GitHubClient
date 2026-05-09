//
//  AppError.swift
//  GitHubClient
//

import Foundation

enum AppError: Error, Equatable {
    case invalidURL
    case network(String)
    case decoding(String)
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

    /// Localized, user-facing message.
    var localizedMessage: String {
        switch self {
        case .invalidURL, .unknown, .decoding:
            return L10n.errorUnknown
        case .network:
            return L10n.errorNetwork
        case .unauthorized:
            return L10n.errorUnauthorized
        case .forbidden, .rateLimited:
            return L10n.errorRateLimit
        case .notFound:
            return L10n.errorNotFound
        case .serverError:
            return L10n.errorServer
        case .oauthCancelled:
            return L10n.errorOAuthCancelled
        case .invalidOAuthCallback, .invalidOAuthState:
            return L10n.errorOAuthCallback
        case .tokenExchangeFailed:
            return L10n.errorTokenExchange
        case .biometricUnavailable:
            return L10n.errorBiometricUnavailable
        case .biometricFailed:
            return L10n.errorBiometricFailed
        }
    }
}
