//
//  ViewState.swift
//  GitHubClient
//

import Foundation

enum ViewState<Value> {
    case idle
    case loading
    case loaded(Value)
    case empty
    case error(AppError)
}
