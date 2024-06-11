//
//  RecentSearchesService.swift
//  SearchableMap
//
//  Created by İbrahim Çetin on 10.06.2024.
//

import MapKit

class RecentSearchesService {
    static let shared = RecentSearchesService()

    private let userDefaults: UserDefaults
    private(set) var recentSearches: [String] {
        didSet {
            save()
        }
    }

    private let key = "RecentSearches"
    var maxSearchCount: Int = 10

    init() {
        self.userDefaults = UserDefaults()
        self.recentSearches = userDefaults.object(forKey: key) as? [String] ?? []
    }

    func add(_ text: String) {
        // If the text is already in recent searches
        // remove it and it will be inserted index 0
        if let index = recentSearches.firstIndex(of: text) {
            recentSearches.remove(at: index)
        }

        if recentSearches.count >= maxSearchCount {
            recentSearches.removeLast()
        }

        recentSearches.insert(text, at: 0)
    }

    func delete(at index: Int) {
        guard index < recentSearches.count else { return }

        recentSearches.remove(at: index)
    }

    func clear() {
        recentSearches = []
    }

    private func save() {
        userDefaults.setValue(recentSearches, forKey: key)
    }
}
