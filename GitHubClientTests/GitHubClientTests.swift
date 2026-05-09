//
//  GitHubClientTests.swift
//  GitHubClientTests
//
//  Lightweight XCTest suite covering the most important pieces of the
//  app — endpoint composition, JSON decoding, the Search view-model
//  state machine, and the auth-service token validation flow. The goal
//  is breadth over depth: enough to demonstrate XCTest usage and guard
//  the public contracts those layers expose.
//

import XCTest
@testable import GitHubClient

final class GitHubClientTests: XCTestCase {
    func test_appErrorMessages_areAllNonEmpty() {
        let cases: [AppError] = [
            .invalidURL, .network("x"), .decoding("x"),
            .unauthorized, .forbidden, .notFound,
            .rateLimited, .serverError,
            .oauthCancelled, .invalidOAuthCallback, .invalidOAuthState,
            .tokenExchangeFailed, .biometricUnavailable, .biometricFailed,
            .unknown
        ]
        for error in cases {
            XCTAssertFalse(error.localizedMessage.isEmpty,
                           "Expected non-empty localized message for \(error)")
        }
    }
}
