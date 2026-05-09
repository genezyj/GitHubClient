//
//  RemoteImageLoader.swift
//  GitHubClient
//
//  Tiny URLSession + NSCache image loader. Used by `AvatarImageView` so the
//  rest of the app does not need to depend on a third-party image library.
//

import UIKit

final class RemoteImageLoader {

    static let shared = RemoteImageLoader()

    private let cache = NSCache<NSURL, UIImage>()
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
        cache.countLimit = 200
    }

    /// Token returned to callers so they can cancel the request when the cell
    /// is reused.
    typealias Token = URLSessionDataTask

    func cachedImage(for url: URL) -> UIImage? {
        return cache.object(forKey: url as NSURL)
    }

    @discardableResult
    func loadImage(from url: URL, completion: @escaping (UIImage?) -> Void) -> Token? {
        if let cached = cache.object(forKey: url as NSURL) {
            completion(cached)
            return nil
        }

        let task = session.dataTask(with: url) { [weak self] data, _, _ in
            guard let data, let image = UIImage(data: data) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            self?.cache.setObject(image, forKey: url as NSURL)
            DispatchQueue.main.async { completion(image) }
        }
        task.resume()
        return task
    }
}
