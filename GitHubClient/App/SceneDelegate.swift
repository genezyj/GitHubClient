//
//  SceneDelegate.swift
//  GitHubClient
//

import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        UITestingConfiguration.applyPerLaunchHooks()
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = AppCoordinator.shared.makeRootViewController()
        window.makeKeyAndVisible()
        self.window = window
    }
}
