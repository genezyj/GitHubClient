//
//  UITestingConfiguration.swift
//  GitHubClient
//
//  Launch-argument plumbing for XCUITest. Not used in normal runs unless the
//  host passes `-uitesting` (see `GitHubClientUITests`).
//

import Foundation

enum UITestingAccessibilityID {
    static let tabHome = "uitest.tab.home"
    static let tabSearch = "uitest.tab.search"
    static let tabProfile = "uitest.tab.profile"

    static let homeRepositoryList = "uitest.home.repository_list"
    static let searchRepositoryList = "uitest.search.repository_list"
    static let searchQueryField = "uitest.search.query"

    static let profileLoginGitHub = "uitest.profile.login_github"
    static let profileLogout = "uitest.profile.logout"

    static let loginMockSignIn = "uitest.login.mock_sign_in"
}

enum UITestingConfiguration {

    private static let uitestingFlag = "-uitesting"
    private static let resetKeychainFlag = "-uitesting_reset_keychain"
    private static let mockLoginFlag = "-uitesting_mock_login"

    static var isRunningUITests: Bool {
        ProcessInfo.processInfo.arguments.contains(uitestingFlag)
    }

    /// Clears the OAuth token from Keychain before services boot (isolated UI tests).
    static var shouldResetKeychainOnLaunch: Bool {
        isRunningUITests && ProcessInfo.processInfo.arguments.contains(resetKeychainFlag)
    }

    /// Shows the mock sign-in affordance on the login screen and allows
    /// `AuthService` to accept a fixture user without calling GitHub.
    static var enableMockLoginEntryPoint: Bool {
        isRunningUITests && ProcessInfo.processInfo.arguments.contains(mockLoginFlag)
    }

    static let mockAccessToken = "uitest-mock-access-token"

    /// Hooks invoked from `SceneDelegate` before `AppCoordinator` starts.
    static func applyPerLaunchHooks() {
        guard shouldResetKeychainOnLaunch else { return }
        try? KeychainSecureStorage().deleteToken()
    }

    static func makeMockGitHubUser() throws -> GitHubUser {
        let json = """
        {
            "id": 42424242,
            "login": "uitest_user",
            "avatar_url": null,
            "html_url": "https://github.com/uitest_user",
            "name": "UI Test User",
            "company": null,
            "blog": null,
            "location": null,
            "email": null,
            "bio": "Mock account for XCUITest",
            "public_repos": 42,
            "followers": 100,
            "following": 7
        }
        """
        let decoder = JSONDecoder()
        return try decoder.decode(GitHubUser.self, from: Data(json.utf8))
    }
}
