//
//  LocalSearchService.swift
//  SearchableMap
//
//  Created by İbrahim Çetin on 7.06.2024.
//

import MapKit
import Combine

class LocalSearchService: NSObject {
    /// A shared instance for the service
    static let shared = LocalSearchService()

    override init() {
        super.init()

        localSearchCompleter.delegate = self
        localSearchCompleter.resultTypes = .pointOfInterest
    }

    var queryFragment: String {
        localSearchCompleter.queryFragment
    }

    private let localSearchCompleter = MKLocalSearchCompleter()
    @Published private(set) var searchCompletionResults: [MKLocalSearchCompletion] = []

    private let localSearchCache = NSCache<NSString, MKLocalSearch.Response>()

    private(set) var searchRegion: MKCoordinateRegion = MKCoordinateRegion(.world) {
        didSet {
            localSearchCompleter.region = searchRegion
        }
    }

    private var lastSearchRegionUpdate: Date?
    private let searchRegionUpdateInterval: Double = 3.0

    func searchCompletion(for queryString: String) {
        if queryString.isEmpty {
            // Cancel if any search is in progress
            localSearchCompleter.cancel()

            // Clear completion results
            searchCompletionResults = []
        }
        
        // Set queryFragment. It will be cleared if searchText is empty
        localSearchCompleter.queryFragment = queryString
    }

    func search(for searchCompletion: MKLocalSearchCompletion) async throws -> [MKMapItem] {
        let request = MKLocalSearch.Request(completion: searchCompletion)

        return try await search(using: request)
    }

    private func search(using searchRequest: MKLocalSearch.Request) async throws -> [MKMapItem] {
        guard let searchText = searchRequest.naturalLanguageQuery as? NSString else {
            return []
        }

        if let response = localSearchCache.object(forKey: searchText) {
            return response.mapItems
        } else {
            searchRequest.region = searchRegion
            searchRequest.resultTypes = .pointOfInterest

            let localSearch = MKLocalSearch(request: searchRequest)

            let response = try await localSearch.start()
            localSearchCache.setObject(response, forKey: searchText)

            return response.mapItems
        }
    }

    func setSearchRegion(_ region: MKCoordinateRegion) {
        if let lastSearchRegionUpdate {
            // if lastSearchRegionUpdate set than
            // check if the interval is greater than searchRegionUpdateInterval
            let interval = Date.now.timeIntervalSince(lastSearchRegionUpdate)

            // interval should be greater than searchRegionUpdateInterval
            guard interval > searchRegionUpdateInterval else { return }
        }
        
        localSearchCompleter.cancel()

        searchRegion = region
        lastSearchRegionUpdate = .now
    }
}

extension LocalSearchService: MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        searchCompletionResults = completer.results
    }
}
