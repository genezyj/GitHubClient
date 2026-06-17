//
//  RepositoryContent.swift
//  GitHubClient
//

import Foundation

struct RepositoryContent: Decodable, Hashable {
    let name: String
    let path: String
    let sha: String?
    let size: Int?
    let type: ContentType
    let downloadUrl: URL?
    let htmlUrl: URL?
    let content: String?
    let encoding: String?

    enum ContentType: String, Decodable {
        case file
        case dir
        case symlink
        case submodule
        case unknown

        init(from decoder: Decoder) throws {
            let raw = try decoder.singleValueContainer().decode(String.self)
            self = ContentType(rawValue: raw) ?? .unknown
        }
    }

    enum CodingKeys: String, CodingKey {
        case name
        case path
        case sha
        case size
        case type
        case downloadUrl = "download_url"
        case htmlUrl = "html_url"
        case content
        case encoding
    }

    var isDirectory: Bool { type == .dir }
    var isFile: Bool { type == .file }

    var decodedTextContent: String? {
        guard encoding == "base64", let content else { return nil }
        let cleaned = content.replacingOccurrences(of: "\n", with: "")
        guard let data = Data(base64Encoded: cleaned) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    var fileKind: RepositoryFileKind {
        guard isFile else { return .unsupported }
        let lower = name.lowercased()
        if lower == "readme" || lower.hasPrefix("readme.") || lower.hasSuffix(".md") || lower.hasSuffix(".markdown") {
            return .markdown
        }
        if RepositoryFileKind.imageExtensions.contains(where: { lower.hasSuffix($0) }) {
            return .image
        }
        if RepositoryFileKind.textExtensions.contains(where: { lower.hasSuffix($0) }) {
            return .text
        }
        return .unsupported
    }
}

enum RepositoryFileKind {
    case markdown
    case text
    case image
    case unsupported

    static let imageExtensions = [".png", ".jpg", ".jpeg", ".gif", ".webp"]

    static let textExtensions = [
        ".swift", ".m", ".mm", ".h", ".c", ".cc", ".cpp", ".hpp",
        ".js", ".jsx", ".ts", ".tsx", ".json", ".yml", ".yaml",
        ".xml", ".html", ".css", ".scss", ".svg", ".md", ".markdown",
        ".txt", ".rb", ".py", ".go", ".rs", ".java", ".kt",
        ".sh", ".zsh", ".bash", ".plist", ".strings", ".sql"
    ]
}
