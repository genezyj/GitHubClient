//
//  APIClient.swift
//  GitHubClient
//

import Foundation

final class APIClient: APIClientProtocol {

    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder

    init(
        baseURL: URL = URL(string: "https://api.github.com")!,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.session = session

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func request<T: Decodable>(_ endpoint: Endpoint, token: String?) async throws -> T {
        let data = try await requestData(endpoint, token: token)
        if T.self == EmptyResponse.self, data.isEmpty {
            return EmptyResponse() as! T
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw AppError.decoding(String(describing: error))
        }
    }

    func requestData(_ endpoint: Endpoint, token: String?) async throws -> Data {
        guard var components = URLComponents(url: baseURL.appendingPathComponent(endpoint.path), resolvingAgainstBaseURL: false) else {
            throw AppError.invalidURL
        }
        if !endpoint.queryItems.isEmpty {
            components.queryItems = endpoint.queryItems
        }
        guard let url = components.url else { throw AppError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.cachePolicy = endpoint.cachePolicy
        request.setValue(endpoint.acceptHeader, forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        if let token, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw AppError.network(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw AppError.unknown
        }

        switch http.statusCode {
        case 200...299:
            return data
        case 401:
            throw AppError.unauthorized
        case 403:
            // GitHub returns 403 for both forbidden and rate limit. The
            // x-ratelimit-remaining header distinguishes the two.
            if let remaining = http.value(forHTTPHeaderField: "x-ratelimit-remaining"), remaining == "0" {
                throw AppError.rateLimited
            }
            throw AppError.forbidden
        case 404:
            throw AppError.notFound
        case 500...599:
            throw AppError.serverError
        default:
            throw AppError.unknown
        }
    }
}
