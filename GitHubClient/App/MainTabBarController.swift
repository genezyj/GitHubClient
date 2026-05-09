//
//  MainTabBarController.swift
//  GitHubClient
//

import UIKit

final class MainTabBarController: UITabBarController {

    private let gitHubService: GitHubServiceProtocol
    private let authService: AuthServiceProtocol
    private let biometricAuth: BiometricAuthProtocol

    init(
        gitHubService: GitHubServiceProtocol,
        authService: AuthServiceProtocol,
        biometricAuth: BiometricAuthProtocol
    ) {
        self.gitHubService = gitHubService
        self.authService = authService
        self.biometricAuth = biometricAuth
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        viewControllers = [makeHomeTab(), makeSearchTab(), makeProfileTab()]
        tabBar.tintColor = .label
    }

    private func makeHomeTab() -> UINavigationController {
        let viewModel = HomeViewModel(service: gitHubService)
        let vc = HomeViewController(viewModel: viewModel)
        vc.title = L10n.homeTitle
        let nav = UINavigationController(rootViewController: vc)
        nav.tabBarItem = UITabBarItem(
            title: L10n.tabHome,
            image: UIImage(systemName: "house"),
            selectedImage: UIImage(systemName: "house.fill")
        )
        nav.navigationBar.prefersLargeTitles = true
        return nav
    }

    private func makeSearchTab() -> UINavigationController {
        let viewModel = SearchViewModel(service: gitHubService)
        let vc = SearchViewController(viewModel: viewModel)
        vc.title = L10n.searchTitle
        let nav = UINavigationController(rootViewController: vc)
        nav.tabBarItem = UITabBarItem(
            title: L10n.tabSearch,
            image: UIImage(systemName: "magnifyingglass"),
            selectedImage: UIImage(systemName: "magnifyingglass.circle.fill")
        )
        nav.navigationBar.prefersLargeTitles = true
        return nav
    }

    private func makeProfileTab() -> UINavigationController {
        let viewModel = ProfileViewModel(
            authService: authService,
            biometricAuth: biometricAuth
        )
        let vc = ProfileViewController(
            viewModel: viewModel,
            authService: authService
        )
        vc.title = L10n.profileTab
        let nav = UINavigationController(rootViewController: vc)
        nav.tabBarItem = UITabBarItem(
            title: L10n.profileTab,
            image: UIImage(systemName: "person.crop.circle"),
            selectedImage: UIImage(systemName: "person.crop.circle.fill")
        )
        nav.navigationBar.prefersLargeTitles = true
        return nav
    }
}
