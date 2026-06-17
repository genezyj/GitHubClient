//
//  RepositoryDetailLayoutTests.swift
//  GitHubClientTests
//

import XCTest
@testable import GitHubClient

@MainActor
final class RepositoryDetailLayoutTests: XCTestCase {

    /// Reproduces the "awesome-ios / awesome-mac" bug: a repo with a long
    /// description and many topics whose content container resolved wider than
    /// the screen, so the page was centered and clipped on both edges. Hosts
    /// the detail VC in a real window + navigation controller (as on device)
    /// and asserts the layout is unambiguous and never wider than the screen.
    func test_detailContent_doesNotOverflowScreenWidth() throws {
        let screenWidth: CGFloat = 390
        let (vc, window) = try makeHostedDetailVC(width: screenWidth, height: 844)
        defer { window.isHidden = true }

        window.layoutIfNeeded()

        guard let scrollView = firstScrollView(in: vc.view) else {
            return XCTFail("Expected a scroll view in the detail layout")
        }
        let contentContainer = scrollView.subviews.first { !($0 is UIImageView) && !$0.subviews.isEmpty }

        // 1. The content must not be wider than the screen (no sideways clip).
        XCTAssertLessThanOrEqual(
            scrollView.contentSize.width, screenWidth + 0.5,
            "Detail content width \(scrollView.contentSize.width) exceeds the \(screenWidth)pt screen"
        )
        if let contentContainer {
            // The content container must fill exactly the screen width: the
            // width preference now outranks the subviews' content resistance,
            // so long descriptions / many topics can no longer stretch it wide.
            XCTAssertEqual(
                contentContainer.bounds.width, screenWidth, accuracy: 0.5,
                "Content container width \(contentContainer.bounds.width) should match the \(screenWidth)pt screen"
            )
        }
    }

    /// The breadcrumb trail must stay tightly left-packed: when it is narrower
    /// than the screen, the trailing spacer (not the "/" separators) absorbs the
    /// slack, so there is no gap before a pill (the stretched-separator bug).
    func test_breadcrumbSeparatorsDoNotStretch() throws {
        let (vc, window) = try makeHostedDetailVC(width: 390, height: 844, path: "docs")
        defer { window.isHidden = true }
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        window.setNeedsLayout()
        window.layoutIfNeeded()

        let separators = breadcrumbSeparators(in: vc.view)
        XCTAssertFalse(separators.isEmpty, "Expected at least one breadcrumb separator")
        for label in separators {
            XCTAssertEqual(
                label.bounds.width, label.intrinsicContentSize.width, accuracy: 0.5,
                "Breadcrumb separator stretched to \(label.bounds.width) (intrinsic \(label.intrinsicContentSize.width)) — gap before the next pill"
            )
        }
    }

    private func breadcrumbSeparators(in root: UIView) -> [UILabel] {
        var labels: [UILabel] = []
        func walk(_ view: UIView) {
            if let label = view as? UILabel, label.text == "/" { labels.append(label) }
            view.subviews.forEach(walk)
        }
        walk(root)
        return labels
    }

    // MARK: Helpers

    private func makeHostedDetailVC(width: CGFloat, height: CGFloat, path: String = "") throws -> (RepositoryDetailViewController, UIWindow) {
        let repo = GitHubRepository.awesomeFixture()
        let service = MockGitHubService()
        service.repositoryResult = .success(repo)
        service.contentsResult = .success([
            .fixture(name: "CONTRIBUTING.md", path: "CONTRIBUTING.md", type: "file"),
            .fixture(name: "Sources", path: "Sources", type: "dir"),
            .fixture(name: "buy_me_a_coffee.png", path: "buy_me_a_coffee.png", type: "file")
        ])
        let auth = try makeAuth()
        let viewModel = RepositoryDetailViewModel(repository: repo, service: service, path: path)
        let vc = RepositoryDetailViewController(viewModel: viewModel, authService: auth)
        let nav = UINavigationController(rootViewController: vc)

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: width, height: height))
        window.rootViewController = nav
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

    private func makeAuth() throws -> AuthService {
        let storage = InMemorySecureStorage()
        let service = MockGitHubService()
        return AuthService(
            service: service,
            storage: storage,
            oauthService: StubOAuthService(),
            sessionTokenGate: SessionTokenGate(storage: storage)
        )
    }
}

private extension GitHubRepository {
    /// A repo shaped like `vsouza/awesome-ios`: long description and a long
    /// list of topics — the content that previously overflowed.
    static func awesomeFixture() -> GitHubRepository {
        let topics = [
            "awesome", "ios", "ios-animation", "ios-libraries", "objective-c",
            "swift", "swift-extensions", "swift-framework", "swift-language",
            "swift-library", "swift-programming"
        ]
        let topicsJSON = topics.map { "\"\($0)\"" }.joined(separator: ", ")
        let json = """
        {
            "id": 99,
            "name": "awesome-ios",
            "full_name": "vsouza/awesome-ios",
            "owner": {
                "id": 1,
                "login": "vsouza",
                "avatar_url": "https://avatars.githubusercontent.com/u/1",
                "html_url": "https://github.com/vsouza"
            },
            "html_url": "https://github.com/vsouza/awesome-ios",
            "description": "A curated list of awesome iOS ecosystem, including Objective-C and Swift Projects, sample code, tools, frameworks, libraries and learning resources.",
            "language": "Swift",
            "stargazers_count": 48000,
            "forks_count": 6800,
            "open_issues_count": 10,
            "topics": [\(topicsJSON)],
            "created_at": "2014-09-15T21:15:07Z",
            "updated_at": "2026-06-15T12:34:56Z"
        }
        """
        return try! JSONDecoder.gitHub.decode(GitHubRepository.self, from: Data(json.utf8))
    }
}
