//
//  GitHubClientUITests.swift
//  GitHubClientUITests
//
//  P2.1 — scenario coverage with stable `accessibilityIdentifier` hooks
//  (only applied in the app when `-uitesting` is passed on launch).
//
//  Search + Home cases call the live GitHub API and require network access.
//

import XCTest

/// Mirrors `UITestingAccessibilityID` in the app target (test bundle cannot import it).
private enum A11y {
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

final class GitHubClientUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func configureApp(_ app: XCUIApplication, resetKeychain: Bool = true, mockLoginEntry: Bool = false) {
        app.launchArguments = ["-uitesting"]
        if resetKeychain { app.launchArguments.append("-uitesting_reset_keychain") }
        if mockLoginEntry { app.launchArguments.append("-uitesting_mock_login") }
    }

    /// Taps the keyboard’s search/return affordance — labels vary by OS language.
    private func tapKeyboardSubmitSearch(_ app: XCUIApplication) {
        let candidates = ["搜索", "Search", "Go", "続行"]
        for label in candidates {
            let key = app.keyboards.buttons[label]
            if key.waitForExistence(timeout: 1), key.isHittable {
                key.tap()
                return
            }
        }
    }

    @MainActor
    func testLaunch_withoutLogin_homeListVisible() throws {
        let app = XCUIApplication()
        configureApp(app, resetKeychain: true, mockLoginEntry: false)
        app.launch()

        let table = app.tables[A11y.homeRepositoryList]
        XCTAssertTrue(table.waitForExistence(timeout: 5))
        XCTAssertTrue(table.cells.element(boundBy: 0).waitForExistence(timeout: 30),
                      "Timed out waiting for at least one Home row — check simulator network / GitHub rate limits.")
    }

    @MainActor
    func testSearch_swift_resultsVisible() throws {
        let app = XCUIApplication()
        configureApp(app, resetKeychain: true, mockLoginEntry: false)
        app.launch()

        app.tabBars.buttons.matching(identifier: A11y.tabSearch).element.tap()

        let searchField = app.searchFields[A11y.searchQueryField]
        XCTAssertTrue(searchField.waitForExistence(timeout: 8), "Search field missing — check UISearchBar / accessibility id wiring.")
        searchField.tap()
        searchField.typeText("swift")
        if app.keyboards.element(boundBy: 0).waitForExistence(timeout: 1.5) {
            tapKeyboardSubmitSearch(app)
        } else {
            // Simulator uses a hardware keyboard; Return still triggers `-editingDidEndOnExit`
            searchField.typeText("\n")
        }

        let table = app.tables[A11y.searchRepositoryList]
        let firstRow = table.cells.element(boundBy: 0)
        XCTAssertTrue(
            firstRow.waitForExistence(timeout: 45),
            "Timed out waiting for the first Swift search row — GitHub API, rate limits, or hardware keyboard Simulation can hide the software keyboard."
        )
    }

    @MainActor
    func testProfile_guest_showsGitHubLoginButton() throws {
        let app = XCUIApplication()
        configureApp(app, resetKeychain: true, mockLoginEntry: false)
        app.launch()

        app.tabBars.buttons.matching(identifier: A11y.tabProfile).element.tap()

        let loginBtn = app.buttons[A11y.profileLoginGitHub]
        XCTAssertTrue(loginBtn.waitForExistence(timeout: 8))
        XCTAssertTrue(loginBtn.isHittable)
    }

    @MainActor
    func testMockLogin_profileShowsLogout() throws {
        let app = XCUIApplication()
        configureApp(app, resetKeychain: true, mockLoginEntry: true)
        app.launch()

        app.tabBars.buttons.matching(identifier: A11y.tabProfile).element.tap()

        XCTAssertTrue(app.buttons[A11y.profileLoginGitHub].waitForExistence(timeout: 5))
        app.buttons[A11y.profileLoginGitHub].tap()

        let mockBtn = app.buttons[A11y.loginMockSignIn]
        XCTAssertTrue(mockBtn.waitForExistence(timeout: 5))
        mockBtn.tap()

        XCTAssertTrue(app.buttons[A11y.profileLogout].waitForExistence(timeout: 8))
    }

    @MainActor
    func testLogout_returnsToGuestState() throws {
        let app = XCUIApplication()
        configureApp(app, resetKeychain: true, mockLoginEntry: true)
        app.launch()

        app.tabBars.buttons.matching(identifier: A11y.tabProfile).element.tap()
        app.buttons[A11y.profileLoginGitHub].tap()
        app.buttons[A11y.loginMockSignIn].tap()
        XCTAssertTrue(app.buttons[A11y.profileLogout].waitForExistence(timeout: 8))

        app.buttons[A11y.profileLogout].tap()

        // Localized alert copy (zh-Hans is the app default development region).
        let alert = app.alerts["确认退出登录？"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        alert.buttons["确认"].tap()

        XCTAssertTrue(app.buttons[A11y.profileLoginGitHub].waitForExistence(timeout: 8))
    }
}
