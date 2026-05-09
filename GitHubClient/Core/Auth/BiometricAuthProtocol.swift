//
//  BiometricAuthProtocol.swift
//  GitHubClient
//

import Foundation

protocol BiometricAuthProtocol {
    func canEvaluateBiometrics() -> Bool
    func authenticate(reason: String) async throws -> Bool
}
