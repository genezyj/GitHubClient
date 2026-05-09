//
//  PKCE.swift
//  GitHubClient
//
//  Authorization Code + PKCE helpers (RFC 7636) and `state` generator.
//

import CryptoKit
import Foundation

struct PKCEPair {
    let verifier: String
    let challenge: String
    /// Always `S256` for this app.
    let method: String
}

enum PKCE {

    /// Generates a fresh PKCE pair using a 64-byte cryptographically
    /// random verifier (well within RFC 7636's 43–128 range after base64url).
    static func generate() -> PKCEPair {
        let verifier = randomURLSafeString(byteCount: 64)
        let challenge = challenge(for: verifier)
        return PKCEPair(verifier: verifier, challenge: challenge, method: "S256")
    }

    /// 32-byte URL-safe random string for the OAuth `state` parameter.
    static func generateState() -> String {
        return randomURLSafeString(byteCount: 32)
    }

    /// `BASE64URL-ENCODE(SHA256(ASCII(verifier)))` per RFC 7636 §4.2.
    static func challenge(for verifier: String) -> String {
        let data = Data(verifier.utf8)
        let digest = SHA256.hash(data: data)
        return Data(digest).base64URLEncodedString()
    }

    private static func randomURLSafeString(byteCount: Int) -> String {
        var bytes = [UInt8](repeating: 0, count: byteCount)
        let status = SecRandomCopyBytes(kSecRandomDefault, byteCount, &bytes)
        if status != errSecSuccess {
            // Extremely unlikely; fall back to UUID-derived randomness so we
            // never crash and still produce a unique-enough value.
            return UUID().uuidString.replacingOccurrences(of: "-", with: "")
        }
        return Data(bytes).base64URLEncodedString()
    }
}

extension Data {
    /// Base64-URL encoding (RFC 4648 §5): `+` → `-`, `/` → `_`, no padding.
    func base64URLEncodedString() -> String {
        return base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
