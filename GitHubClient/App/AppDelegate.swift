//
//  AppDelegate.swift
//  GitHubClient
//

import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {

    /// Fallback / explicit configuration wiring (manifest names must match `SupportingFiles/GitHubClient-Info.plist`).
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }
}
