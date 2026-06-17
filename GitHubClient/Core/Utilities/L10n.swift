//
//  L10n.swift
//  GitHubClient
//
//  Strongly typed wrappers around `NSLocalizedString`. Keeps view layer free
//  of magic-string keys.
//

import Foundation

enum L10n {
    static let tabHome = NSLocalizedString("tab.home", comment: "Home tab title")
    static let tabSearch = NSLocalizedString("tab.search", comment: "Search tab title")
    static let profileTab = NSLocalizedString("tab.profile", comment: "Profile tab title")

    static let homeTitle = NSLocalizedString("home.title", comment: "Home screen title")

    static let searchTitle = NSLocalizedString("search.title", comment: "Search screen title")
    static let searchPlaceholder = NSLocalizedString("search.placeholder", comment: "Search bar placeholder")
    static let searchInitialEmpty = NSLocalizedString("search.initial_empty", comment: "Initial empty state on search")
    static let searchNoResults = NSLocalizedString("search.no_results", comment: "No results found")

    static let profileNotLoggedIn = NSLocalizedString("profile.not_logged_in", comment: "Guest profile state")
    static let profileLoginWithGitHub = NSLocalizedString("profile.login_with_github", comment: "Sign in with GitHub button")
    static let profileLoginWithBiometrics = NSLocalizedString("profile.login_with_biometrics", comment: "Biometric login button")
    static let profileLogout = NSLocalizedString("profile.logout", comment: "Logout button")
    static let profileLogoutConfirmTitle = NSLocalizedString("profile.logout_confirm_title", comment: "Logout confirmation alert title")
    static let profileLogoutConfirmMessage = NSLocalizedString("profile.logout_confirm_message", comment: "Logout confirmation alert message")
    /// Ends the on-screen session but keeps Keychain token for Face ID / Touch ID.
    static let profileLogoutSignOutOnly = NSLocalizedString("profile.logout_sign_out_only", comment: "Sign out locally but keep saved token")
    /// Deletes Keychain token so biometric re-login is no longer available.
    static let profileLogoutRemoveCredentials = NSLocalizedString("profile.logout_remove_credentials", comment: "Sign out and delete saved token")
    static let profileLoginHint = NSLocalizedString("profile.login_hint", comment: "Hint shown to guest users")

    static let loginTitle = NSLocalizedString("login.title", comment: "Login screen title")
    static let loginHeadline = NSLocalizedString("login.headline", comment: "Login screen headline")
    static let loginSignInWithGitHub = NSLocalizedString("login.sign_in_with_github", comment: "Sign in with GitHub button")
    static let loginNoteOAuth = NSLocalizedString("login.note_oauth", comment: "Explanatory note on OAuth login screen")
    static let loginMissingCredentials = NSLocalizedString("login.missing_credentials", comment: "Inline message shown when OAuthConfig still has placeholder credentials")
    static let loginBiometricReason = NSLocalizedString("login.biometric_reason", comment: "Reason shown by Face ID/Touch ID prompt")

    static let commonCancel = NSLocalizedString("common.cancel", comment: "Cancel button")
    static let commonConfirm = NSLocalizedString("common.confirm", comment: "Confirm button")
    static let commonOK = NSLocalizedString("common.ok", comment: "OK button")
    static let commonLoading = NSLocalizedString("common.loading", comment: "Loading text")

    static let errorTitle = NSLocalizedString("error.title", comment: "Error state title")
    static let errorNetwork = NSLocalizedString("error.network", comment: "Network failure message")
    static let errorUnauthorized = NSLocalizedString("error.unauthorized", comment: "Unauthorized message")
    static let errorRateLimit = NSLocalizedString("error.rate_limit", comment: "Rate limit message")
    static let errorNotFound = NSLocalizedString("error.not_found", comment: "Not found message")
    static let errorServer = NSLocalizedString("error.server", comment: "Server failure message")
    static let errorUnknown = NSLocalizedString("error.unknown", comment: "Unknown error message")
    static let errorRetry = NSLocalizedString("error.retry", comment: "Retry button")
    static let errorOAuthCancelled = NSLocalizedString("error.oauth_cancelled", comment: "User cancelled the OAuth flow")
    static let errorOAuthCallback = NSLocalizedString("error.oauth_callback", comment: "Invalid OAuth callback or state mismatch")
    static let errorTokenExchange = NSLocalizedString("error.token_exchange", comment: "Token exchange failure")
    static let errorBiometricUnavailable = NSLocalizedString("error.biometric_unavailable", comment: "Biometric unavailable")
    static let errorBiometricFailed = NSLocalizedString("error.biometric_failed", comment: "Biometric failed")

    static let repoStars = NSLocalizedString("repo.stars", comment: "Stars label")
    static let repoForks = NSLocalizedString("repo.forks", comment: "Forks label")
    static let repoUpdated = NSLocalizedString("repo.updated", comment: "Updated date label")

    static let detailCreated = NSLocalizedString("detail.created", comment: "Created date label on detail screen")
    static let detailNoDescription = NSLocalizedString("detail.no_description", comment: "Placeholder when repo description is empty")
    static let detailOpenOnGitHub = NSLocalizedString("detail.open_on_github", comment: "Open in Safari button on detail screen")

    static let profileRepos = NSLocalizedString("profile.repos", comment: "Public repos count label")
    static let profileFollowers = NSLocalizedString("profile.followers", comment: "Followers count label")
    static let profileFollowing = NSLocalizedString("profile.following", comment: "Following count label")
    static let profileStarredRepositories = NSLocalizedString("profile.starred_repositories", comment: "Starred repositories section title")
    static let profileNoStarredRepositories = NSLocalizedString("profile.no_starred_repositories", comment: "No starred repositories profile message")

    static let repoBrowserRoot = NSLocalizedString("repo_browser.root", comment: "Repository browser root folder title")
    static let repoBrowserEmpty = NSLocalizedString("repo_browser.empty", comment: "Repository browser empty folder message")
    static let repoBrowserFolder = NSLocalizedString("repo_browser.folder", comment: "Repository browser folder item subtitle")
    static let repoBrowserFile = NSLocalizedString("repo_browser.file", comment: "Repository browser file item subtitle")
    static let repoBrowserUnsupportedItem = NSLocalizedString("repo_browser.unsupported_item", comment: "Repository browser unsupported item subtitle")

    static let starLoginRequiredTitle = NSLocalizedString("star.login_required_title", comment: "Star login alert title")
    static let starLoginRequiredMessage = NSLocalizedString("star.login_required_message", comment: "Star login alert message")

    static func fileUnsupportedPreview(_ filename: String) -> String {
        return String(format: NSLocalizedString("file.unsupported_preview", comment: "Unsupported file preview message"), filename)
    }
}
