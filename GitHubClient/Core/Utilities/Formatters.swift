//
//  Formatters.swift
//  GitHubClient
//

import Foundation

enum CompactNumberFormatter {
    /// Formats large counts in a compact form, e.g. 1500 -> "1.5K", 2_300_000 -> "2.3M".
    static func string(from value: Int) -> String {
        let absValue = abs(value)
        switch absValue {
        case 0..<1_000:
            return "\(value)"
        case 1_000..<1_000_000:
            let v = Double(value) / 1_000.0
            return String(format: "%.1fK", v)
        default:
            let v = Double(value) / 1_000_000.0
            return String(format: "%.1fM", v)
        }
    }
}

enum RelativeDateFormatterUtil {
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    static func string(from date: Date) -> String {
        return formatter.string(from: date)
    }
}
