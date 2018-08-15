//
//  SearchUsersDataSource.swift
//  FluxWithRxSwift
//
//  Created by 鈴木大貴 on 2018/08/10.
//  Copyright © 2018年 marty-suzuki. All rights reserved.
//

import UIKit

final class SearchUsersDataSource: NSObject {

    private let flux: Flux

    private let cellIdentifier = "Cell"
    private var imageDataList: [IndexPath: Data] = [:]
    private let imageCache: NSCache<NSURL, NSData> = {
        let cache = NSCache<NSURL, NSData>()
        cache.countLimit = 50
        return cache
    }()
    private var blankImage: UIImage?

    init(flux: Flux) {
        self.flux = flux

        super.init()
    }

    func configure(_ tableView: UITableView) {
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: cellIdentifier)
        tableView.dataSource = self
        tableView.delegate = self
    }
}

extension SearchUsersDataSource: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return flux.userStore.users.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath)

        let user = flux.userStore.users[indexPath.row]
        cell.textLabel?.text = user.login
        setImage(to: cell, url: user.avatarURL, indexPath: indexPath, tableView: tableView)

        return cell
    }
}

extension SearchUsersDataSource: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let user = flux.userStore.users[indexPath.row]
        flux.userActionCreator.setSelectedUser(user)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if let query = flux.userStore.query, let next = flux.userStore.pagination?.next,
            flux.userStore.pagination?.last != nil &&
            (scrollView.contentSize.height - scrollView.bounds.size.height) <= scrollView.contentOffset.y &&
            !flux.userStore.isFetching {
            flux.userActionCreator.searchUsers(query: query, page: next)
        }
    }
}

extension SearchUsersDataSource {
    func setImage(to cell: UITableViewCell, url: URL, indexPath: IndexPath, tableView: UITableView) {
        let setImage: (Data, Bool) -> () = { data, animated in
            guard let imageView = cell.imageView else {
                return
            }

            let image = UIImage(data: data)
            if animated {
                UIView.transition(with: imageView,
                                  duration: 0.3,
                                  options: .transitionCrossDissolve,
                                  animations: { imageView.image = image },
                                  completion: nil)
            } else {
                imageView.image = image
            }
        }

        if let data = imageCache.object(forKey: url as NSURL) as Data? {
            setImage(data, false)
        } else {
            let image: UIImage?
            if let blankImage = blankImage {
                image = blankImage
            } else {
                let size = CGSize(width: cell.bounds.size.height, height: cell.bounds.size.height)
                let rect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
                UIGraphicsBeginImageContextWithOptions(size, false, 1)
                UIColor.white.set()
                UIRectFill(rect)
                image = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()
                blankImage = image
            }
            cell.imageView?.image = image

            URLSession.shared.dataTask(with: url) { [indexPath, url, weak self] data, _, _ in
                guard let data = data else {
                    return
                }
                self?.imageCache.setObject(data as NSData, forKey: url as NSURL)
                DispatchQueue.main.async {
                    guard tableView.indexPath(for: cell) == indexPath else {
                        return
                    }
                    setImage(data, true)
                }
            }.resume()
        }
    }
}
