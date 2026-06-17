//
//  APIClientProtocol.swift
//  GitHubClient
//

import Foundation

protocol APIClientProtocol {
    /// Perform a request and decode the response body as `T`.
    /// - Parameters:
    ///   - endpoint: Endpoint description (path + query + method).
    ///   - token: Optional bearer token. When supplied it is sent as
    ///     `Authorization: Bearer <token>`.
    func request<T: Decodable>(_ endpoint: Endpoint, token: String?) async throws -> T

    /// Perform a request and return the raw response body. Used for GitHub
    /// rendered markdown HTML and other non-JSON payloads.
    func requestData(_ endpoint: Endpoint, token: String?) async throws -> Data
}

struct EmptyResponse: Decodable {}
