//
//  ProfileLayoutTests.swift
//  GitHubClientTests
//

import XCTest
@testable import GitHubClient

@MainActor
final class ProfileLayoutTests: XCTestCase {

    /// Reproduces the "Starred 仓库" / `bug6` clipping: a starred-repo card with a
    /// wide single-line name stretched the profile content container past the
    /// screen because its equal-width preference only tied (`.defaultHigh`) with
    /// the cards' content-compression resistance. The over-wide container was then
    /// centered, clipping the section title on the left and card text on the right.
    /// Hosts the profile VC in a real window and asserts nothing overflows the
    /// screen width and the title stays fully visible at the leading edge.
    func test_profileContent_withWideStarredCard_doesNotOverflowScreenWidth() throws {
        let screenWidth: CGFloat = 390
        let (vc, window) = try makeHostedLoggedInProfile(width: screenWidth, height: 844)
        defer { window.isHidden = true }

        RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        window.setNeedsLayout()
        window.layoutIfNeeded()

        guard let scrollView = firstScrollView(in: vc.view) else {
            return XCTFail("Expected a scroll view in the profile layout")
        }
        let contentContainer = scrollView.subviews.first { !$0.subviews.isEmpty }

        // The scrollable content must never be wider than the screen.
        XCTAssertLessThanOrEqual(
            scrollView.contentSize.width, screenWidth + 0.5,
            "Profile content width \(scrollView.contentSize.width) exceeds the \(screenWidth)pt screen"
        )
        if let contentContainer {
            XCTAssertEqual(
                contentContainer.bounds.width, screenWidth, accuracy: 0.5,
                "Content container width \(contentContainer.bounds.width) should match the \(screenWidth)pt screen — a wide card stretched it"
            )
        }

        // The starred section title must stay within the screen and show its full text.
        guard let title = findLabel(withText: L10n.profileStarredRepositories, in: vc.view) else {
            return XCTFail("Expected the starred section title label to be visible")
        }
        let titleFrame = title.convert(title.bounds, to: window)
        XCTAssertGreaterThanOrEqual(
            titleFrame.minX, -0.5,
            "Starred title overflows the left screen edge (minX \(titleFrame.minX)) — it would clip to a partial word"
        )
        XCTAssertLessThanOrEqual(
            titleFrame.maxX, screenWidth + 0.5,
            "Starred title overflows the right screen edge (maxX \(titleFrame.maxX))"
        )
    }

    // MARK: Helpers

    private func makeHostedLoggedInProfile(width: CGFloat, height: CGFloat) throws -> (ProfileViewController, UIWindow) {
        let storage = InMemorySecureStorage(initialToken: "token")
        let service = MockGitHubService()
        service.userResult = .success(.fixture())
        service.starredRepositoriesResult = .success([GitHubRepository.wideNameFixture()])
        let auth = AuthService(
            service: service,
            storage: storage,
            oauthService: StubOAuthService(),
            sessionTokenGate: SessionTokenGate(storage: storage)
        )
        let viewModel = ProfileViewModel(
            authService: auth,
            biometricAuth: StubBiometricAuth(),
            service: service
        )
        let vc = ProfileViewController(viewModel: viewModel, authService: auth)

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: width, height: height))
        window.rootViewController = vc
        window.isHidden = false
        window.layoutIfNeeded()
        return (vc, window)
    }

    private func firstScrollView(in root: UIView) -> UIScrollView? {
        if let scroll = root as? UIScrollView { return scroll }
        for subview in root.subviews {
            if let found = firstScrollView(in: subview) { return found }
        }
        return nil
    }

    private func findLabel(withText text: String, in root: UIView) -> UILabel? {
        var found: UILabel?
        func walk(_ view: UIView) {
            if found != nil { return }
            if let label = view as? UILabel, label.text == text, !label.isHidden {
                found = label
                return
            }
            view.subviews.forEach(walk)
        }
        walk(root)
        return found
    }
}

private extension GitHubRepository {
    /// A starred repo whose single-line name is far wider than the screen — the
    /// content that stretched the profile container and clipped the layout.
    static func wideNameFixture() -> GitHubRepository {
        let longName = String(repeating: "very-long-repository-name", count: 4)
        let json = """
        {
            "id": 99,
            "name": "\(longName)",
            "full_name": "octocat/\(longName)",
            "owner": {
                "id": 1,
                "login": "octocat",
                "avatar_url": "https://avatars.githubusercontent.com/u/1",
                "html_url": "https://github.com/octocat"
            },
            "html_url": "https://github.com/octocat/\(longName)",
            "description": "A curated list of awesome iOS ecosystem, including Objective-C and Swift Projects, sample code, tools, frameworks, libraries and learning resources.",
            "language": "Swift",
            "stargazers_count": 48000,
            "forks_count": 6800,
            "open_issues_count": 10,
            "topics": [],
            "created_at": "2014-09-15T21:15:07Z",
            "updated_at": "2026-06-15T12:34:56Z"
        }
        """
        return try! JSONDecoder.gitHub.decode(GitHubRepository.self, from: Data(json.utf8))
    }
}
