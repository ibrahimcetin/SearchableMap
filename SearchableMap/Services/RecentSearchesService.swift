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
        // Recent searches should not contain the same text
        guard !recentSearches.contains(text) else { return }

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

    func updateRecent(_ text: String) {
        // Make sure given text is in the recent searches
        guard let index = recentSearches.firstIndex(of: text) else { return }

        delete(at: index)
        add(text)
    }

    private func save() {
        userDefaults.setValue(recentSearches, forKey: key)
    }
}
