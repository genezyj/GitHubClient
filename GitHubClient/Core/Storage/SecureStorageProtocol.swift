//
//  SecureStorageProtocol.swift
//  GitHubClient
//

import Foundation

protocol SecureStorageProtocol {
    func saveToken(_ token: String) throws
    func readToken() throws -> String?
    func deleteToken() throws
}
