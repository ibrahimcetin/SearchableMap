//
//  MainViewController.swift
//  SearchableMap
//
//  Created by İbrahim Çetin on 6.06.2024.
//

import Combine
import CoreLocation
import MapKit
import UIKit

class MainViewController: UIViewController {
    private let locationManager = CLLocationManager()

    private let localSearchService = LocalSearchService.shared
    private var isUserLocationRequested = false

    private var localSearchCompletionResults = [MKLocalSearchCompletion]() {
        didSet {
            if willAddAnnotations {
                Task { @MainActor in
                    await addAnnotations(localSearchCompletionResults, showAnnotations: false)
                    isSearching = false
                }
            }
        }
    }
    /// If this is true, ``MainViewController/localSearchCompletionResults``'s elements will be searched to get the locations and the annotations will be added
    private var willAddAnnotations = false {
        didSet {
            // Remove all annotations if searchText is changed
            if willAddAnnotations == false {
                mapView.removeAnnotations(mapView.annotations)
            }

            // Trigger addAnnotations because the localSearchCompletionResults
            // observer won't be called.
            if willAddAnnotations == true {
                Task { @MainActor in
                    await addAnnotations(localSearchCompletionResults, showAnnotations: true)
                    isSearching = false
                }
            }
        }
    }

    private var subscriptions: Set<AnyCancellable> = []

    private let searchSheetController = SearchSheetViewController()
    private var selectedSearchCompletionObserver: NSKeyValueObservation!

    private let mapView: MKMapView = {
        let mapView = MKMapView()
        mapView.translatesAutoresizingMaskIntoConstraints = false

        mapView.userTrackingMode = .follow
        mapView.showsUserTrackingButton = true

        return mapView
    }()

    private let lookAroundController = MKLookAroundViewController()
    private let lookAroundContainerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false

        view.layer.masksToBounds = true
        view.layer.cornerRadius = 12

        view.alpha = 0

        return view
    }()

    private let searchAreaButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false

        // Set the shape
        button.configuration = .bordered()
        button.configuration?.cornerStyle = .capsule
        // Set the background
        let blurView = UIBlurEffect(style: .systemThinMaterial)
        let materialView = UIVisualEffectView(effect: blurView)
        button.configuration?.background.backgroundColor = .tertiarySystemBackground
        // Set the title
        button.setTitle("Search this area", for: .normal)
        // Hide the button
        button.alpha = 0

        return button
    }()
    private var searchAreaButtonVisible: Bool = false {
        didSet {
            guard !localSearchService.queryFragment.isEmpty else { return }

            UIView.transition(with: searchAreaButton, duration: 0.5, options: .transitionCrossDissolve) {
                self.searchAreaButton.alpha = self.searchAreaButtonVisible ? 1 : 0
            }
        }
    }

    private let searchingMapSymbol: UIImageView = {
        let view = UIImageView(image: UIImage(named: "map.searching"))
        view.translatesAutoresizingMaskIntoConstraints = false

        view.addSymbolEffect(.variableColor.iterative.hideInactiveLayers.reversing)
        view.alpha = 0

        return view
    }()
    private var isSearching: Bool = false {
        didSet {
            searchingMapSymbol.alpha = isSearching ? 1 : 0
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        locationManager.delegate = self

        layoutMapView()

        layoutSearchAreaButton()
        layoutSearchingMapSymbol()

        layoutLookAroundContainerView()

        searchSheetController.searchBar.delegate = self

        localSearchService.$searchCompletionResults
            .receive(on: OperationQueue.main)
            .sink { [weak self] searchCompletions in
                guard let self else { return }

                self.localSearchCompletionResults = searchCompletions
            }
            .store(in: &subscriptions)

        selectedSearchCompletionObserver = searchSheetController.observe(\.selectedSearchCompletion) { [weak self] controller, change in
            Task { @MainActor in
                guard let self else { return }

                guard let searchCompletion = controller.selectedSearchCompletion else { return }

                do {
                    let annotation = try await self.addAnnotation(searchCompletion: searchCompletion)
                    self.mapView.selectAnnotation(annotation, animated: true)

                    self.searchSheetController.searchBar.resignFirstResponder()
                } catch {
                    self.showErrorAlert(message: error.localizedDescription)
                }
            }
        }

    }

    override func viewDidAppear(_ animated: Bool) {
        // Request user location to be able to center it
        // We request the location after viewDidApper because mapView follow user location.
        // So mapView update the displaying region after viewDidLoad but we don't update localSearchService region in its delegate.
        // As a result we need to request it after viewDidAppear and update the service region from locationManager delegate.
        if isUserLocationRequested == false {
            locationManager.requestWhenInUseAuthorization()
            locationManager.requestLocation()
            isUserLocationRequested = true
        }

        // Configure the search sheet
        configureSheet(searchSheetController)

        // If lookAroundView is not showing present search sheet
        if lookAroundContainerView.alpha == 0 {
            present(searchSheetController, animated: true)
        }
    }

    private func layoutMapView() {
        mapView.delegate = self

        // Add mapView as subview
        view.addSubview(mapView)

        // Add mapView constraints
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: mapView.topAnchor),
            view.bottomAnchor.constraint(equalTo: mapView.bottomAnchor),
            view.leadingAnchor.constraint(equalTo: mapView.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: mapView.trailingAnchor)
        ])
    }

    private func layoutSearchAreaButton() {
        view.addSubview(searchAreaButton)

        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: searchAreaButton.topAnchor, constant: -64),
            view.centerXAnchor.constraint(equalTo: searchAreaButton.centerXAnchor),
        ])

        searchAreaButton.addTarget(self, action: #selector(searchAreaButtonTapped(_:)), for: .touchUpInside)
    }

    @objc private func searchAreaButtonTapped(_ sender: UIButton) {
        // If user did not press search button on the keyboard and insted
        // select from search result, willAddAnnotations stay false.
        // So we need to make it true only if it is false to be able to add annotations
        // and not to trigger addAnnotations method twice
        if willAddAnnotations == false {
            willAddAnnotations = true
        }

        isSearching = true

        // Update service's search region
        localSearchService.setSearchRegion(mapView.region)

        // Hide the button
        searchAreaButtonVisible = false
    }

    private func layoutSearchingMapSymbol() {
        view.addSubview(searchingMapSymbol)

        NSLayoutConstraint.activate([
            searchAreaButton.centerYAnchor.constraint(equalTo: searchingMapSymbol.centerYAnchor),
            searchAreaButton.heightAnchor.constraint(equalTo: searchingMapSymbol.heightAnchor, multiplier: 1),
            searchingMapSymbol.widthAnchor.constraint(equalTo: searchingMapSymbol.heightAnchor, multiplier: 1),
            view.safeAreaLayoutGuide.leadingAnchor.constraint(equalTo: searchingMapSymbol.leadingAnchor, constant: -5)
        ])
    }

    private func layoutLookAroundContainerView() {
        // Add MKLookAroundViewController as child view controller
        self.addChild(lookAroundController)

        lookAroundController.view.translatesAutoresizingMaskIntoConstraints = false
        lookAroundContainerView.addSubview(lookAroundController.view)

        view.addSubview(lookAroundContainerView)

        NSLayoutConstraint.activate([
            lookAroundContainerView.topAnchor.constraint(equalTo: lookAroundController.view.topAnchor),
            lookAroundContainerView.leadingAnchor.constraint(equalTo: lookAroundController.view.leadingAnchor),
            lookAroundContainerView.trailingAnchor.constraint(equalTo: lookAroundController.view.trailingAnchor),
            lookAroundContainerView.bottomAnchor.constraint(equalTo: lookAroundController.view.bottomAnchor)
        ])

        NSLayoutConstraint.activate([
            view.safeAreaLayoutGuide.bottomAnchor.constraint(equalTo: lookAroundContainerView.bottomAnchor),
            view.safeAreaLayoutGuide.leadingAnchor.constraint(equalTo: lookAroundContainerView.leadingAnchor, constant: -20),
            view.safeAreaLayoutGuide.trailingAnchor.constraint(equalTo: lookAroundContainerView.trailingAnchor, constant: 20),
            lookAroundContainerView.heightAnchor.constraint(equalToConstant: 150)
        ])

        lookAroundController.didMove(toParent: self)
    }

    private func configureSheet(_ viewController: UIViewController) {
        guard let sheet = searchSheetController.sheetPresentationController else { return }

        sheet.detents = [.custom(resolver: { _ in 200 }), .medium()]
        sheet.largestUndimmedDetentIdentifier = .medium
        sheet.prefersEdgeAttachedInCompactHeight = true
        sheet.widthFollowsPreferredContentSizeWhenEdgeAttached = true
        sheet.prefersGrabberVisible = true
        sheet.delegate = self
    }

    private func addAnnotations(_ searchCompletions: [MKLocalSearchCompletion], showAnnotations: Bool) async {
        for searchCompletion in searchCompletions {
            do {
                try await addAnnotation(searchCompletion: searchCompletion)
            } catch {
                showErrorAlert(message: error.localizedDescription)
            }
        }
        
        if showAnnotations {
            mapView.showAnnotations(mapView.annotations, animated: true)
        }
    }

    /// Add new annotation to mapView.
    ///
    /// - Returns:The annotation which added to mapView
    ///
    /// If the annotation previously added, won't add new one. Just returns existing annotation.
    @discardableResult
    private func addAnnotation(searchCompletion: MKLocalSearchCompletion) async throws -> any MKAnnotation {
        let annotation = try await self.annotation(from: searchCompletion)

        if let foundAnnotation = self.mapView.annotations.first(where: { $0.coordinate == annotation.coordinate }) {
            // If the annotation already added return it
            return foundAnnotation
        } else {
            // Else add and return it
            self.mapView.addAnnotation(annotation)
            return annotation
        }
    }

    private func annotation(from searchCompletion: MKLocalSearchCompletion) async throws -> any MKAnnotation {
        // Search mapItems from searchCompletion
        let mapItems = try await self.localSearchService.search(for: searchCompletion)
        // Get the last mapItem
        guard let mapItem = mapItems.last else { throw MKError(.placemarkNotFound) }

        // Create annotation
        let annotation = MKPointAnnotation()
        annotation.coordinate = mapItem.placemark.coordinate

        return annotation
    }

    private func showLookAroundView(coordinate: CLLocationCoordinate2D) async throws {
        let lookAroundRequest = MKLookAroundSceneRequest(coordinate: coordinate)
        let scene = try await lookAroundRequest.scene
        lookAroundController.scene = scene

        searchSheetController.dismiss(animated: true)

        UIView.transition(with: lookAroundContainerView, duration: 0.5) {
            self.lookAroundContainerView.alpha = 1
        }
    }

    private func showErrorAlert(message: String) {
        let alert = UIAlertController(title: "Something Went Wrong", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: String(localized: "Ok", comment: "Alert dismiss action"), style: .default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
}

extension MainViewController: UISheetPresentationControllerDelegate {
    func presentationControllerShouldDismiss(_: UIPresentationController) -> Bool {
        lookAroundContainerView.alpha == 1
    }
}

extension MainViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        searchAreaButtonVisible = true
    }

    func mapView(_ mapView: MKMapView, didSelect annotation: any MKAnnotation) {
        mapView.setCenter(annotation.coordinate, animated: true)

        Task {
            do {
                try await self.showLookAroundView(coordinate: annotation.coordinate)
            } catch {
                showErrorAlert(message: error.localizedDescription)
            }
        }
    }

    func mapView(_ mapView: MKMapView, didDeselect annotation: any MKAnnotation) {
        // we need to put a delay here because if user select another annotation while
        // an annotation already selected, unnecassary presentation of searchSheet will occur
        DispatchQueue.main.asyncAfter(deadline: .now() + .nanoseconds(1)) {
            guard mapView.selectedAnnotations.isEmpty else { return }

            self.lookAroundContainerView.alpha = 0

            self.configureSheet(self.searchSheetController)
            self.present(self.searchSheetController, animated: true)
        }
    }
}

extension MainViewController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }

        // Update mapView region
        mapView.centerCoordinate = location.coordinate

        // Set search region for the service
        localSearchService.setSearchRegion(mapView.region)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        showErrorAlert(message: error.localizedDescription)
    }
}


extension MainViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        willAddAnnotations = false
        searchAreaButtonVisible = false

        localSearchService.setSearchRegion(mapView.region)
        localSearchService.searchCompletion(for: searchText)
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        // When search button clicked start the coordinate search
        // and add the annotations on mapView
        willAddAnnotations = true

        // Save the search text to recent searches
        if let searchText = searchBar.text {
            RecentSearchesService.shared.add(searchText)
        }


        searchBar.resignFirstResponder()
    }
}
