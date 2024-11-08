//
//  SearchSheetViewController.swift
//  SearchableMap
//
//  Created by İbrahim Çetin on 6.06.2024.
//

import UIKit
import MapKit
import Combine

class SearchSheetViewController: UIViewController {
    private let localSearchService = LocalSearchService.shared
    private var subscriptions: Set<AnyCancellable> = []

    private var localSearchCompletionResults: [MKLocalSearchCompletion] = [] {
        didSet {
            tableView.reloadData()

            contentUnavailableView.alpha = isNothingFound ? 1 : 0
        }
    }

    @objc dynamic private(set) var selectedSearchCompletion: MKLocalSearchCompletion?

    private let tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.translatesAutoresizingMaskIntoConstraints = false

        tableView.sectionHeaderTopPadding = 0

        // Register reuseable cell to tableView
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "RecentSearchCell")
        tableView.register(SearchCompletionTableViewCell.self, forCellReuseIdentifier: SearchCompletionTableViewCell.identifier)

        return tableView
    }()

    /// If searchBar text is empty or nil, recents will show on tableView
    private var isRecentsShowing: Bool {
        searchBar.text?.isEmpty ?? false
    }

    let searchBar: UISearchBar = {
        let bar = UISearchBar()
        bar.translatesAutoresizingMaskIntoConstraints = false

        bar.searchBarStyle = .minimal

        return bar
    }()

    let contentUnavailableView = {
        let view = UIContentUnavailableView(configuration: .search())
        view.translatesAutoresizingMaskIntoConstraints = false

        view.alpha = 0

        return view
    }()
    private var isNothingFound: Bool {
        localSearchCompletionResults.isEmpty && !localSearchService.queryFragment.isEmpty
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        layoutMaterialBackground()

        layoutSearchBar()
        configureSearchBarPlaceholder()

        layoutTableView()

        layoutContentUnavailableView()

        localSearchService.$searchCompletionResults
            .receive(on: OperationQueue.main)
            .sink { [weak self] searchCompletions in
                guard let self else { return }
                self.localSearchCompletionResults = searchCompletions
            }
            .store(in: &subscriptions)
    }

    private func layoutMaterialBackground() {
        let blurEffect = UIBlurEffect(style: .systemThinMaterial)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.translatesAutoresizingMaskIntoConstraints = false

        view.insertSubview(blurView, at: 0)

        NSLayoutConstraint.activate([
          blurView.topAnchor.constraint(equalTo: view.topAnchor),
          blurView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
          blurView.heightAnchor.constraint(equalTo: view.heightAnchor),
          blurView.widthAnchor.constraint(equalTo: view.widthAnchor)
        ])

        // Clear view background
        view.backgroundColor = .clear

        // Clear tableView background
        tableView.backgroundColor = .clear
    }

    private func layoutSearchBar() {
        view.addSubview(searchBar)

        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    private func configureSearchBarPlaceholder() {
        let placeholderTexts: [LocalizedStringResource] = ["a restaurant", "a gas station", "a zoo", "a park", "a museum"]

        var iterator = placeholderTexts.makeIterator()
        let timer = Timer(timeInterval: 3, repeats: true) { timer in
            guard let text = self.searchBar.text, text.isEmpty else { return }

            if let text = iterator.next() {
                UIView.transition(with: self.searchBar, duration: 0.3, options: .transitionCrossDissolve) {
                    self.searchBar.placeholder = String(localized: "Search \(text)")
                }
            } else {
                iterator = placeholderTexts.makeIterator()
                timer.fire()
            }
        }

        timer.fire()
        RunLoop.current.add(timer, forMode: .default)
    }

    private func layoutTableView() {
        tableView.dataSource = self
        tableView.delegate = self

        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
        ])

        view.keyboardLayoutGuide.usesBottomSafeArea = false
    }

    private func layoutContentUnavailableView() {
        view.addSubview(contentUnavailableView)

        NSLayoutConstraint.activate([
            contentUnavailableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor),
            contentUnavailableView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            contentUnavailableView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            contentUnavailableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }
}

extension SearchSheetViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        isRecentsShowing ? RecentSearchesService.shared.recentSearches.count : localSearchCompletionResults.count
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let label = UILabel()
        label.text = isRecentsShowing ? String(localized: "Recent Searches") : String(localized: "Search Results")
        label.font = .preferredFont(forTextStyle: .callout, compatibleWith: UITraitCollection(legibilityWeight: .bold))
        label.textColor = .secondaryLabel

        let clearButton = UIButton(type: .system)
        clearButton.setTitle(String(localized: "Clear", comment: "Table view's clear recent searches button text"), for: .normal)
        clearButton.alpha = isRecentsShowing ? 1 : 0

        clearButton.addAction(UIAction(handler: { _ in
            RecentSearchesService.shared.clear()
            tableView.reloadData()
        }) , for: .touchUpInside)

        let stackView = UIStackView(arrangedSubviews: [label, clearButton])
        stackView.axis = .horizontal
        stackView.distribution = .fill

        stackView.layoutMargins = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10)
        stackView.isLayoutMarginsRelativeArrangement = true

        return stackView
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: UITableViewCell

        if isRecentsShowing {
            cell = tableView.dequeueReusableCell(withIdentifier: "RecentSearchCell", for: indexPath)

            let recentSearch = RecentSearchesService.shared.recentSearches[indexPath.row]

            var configuration = cell.defaultContentConfiguration()
            configuration.text = recentSearch

            cell.contentConfiguration = configuration
        } else {
            // Dequeue a cell from the pool
            let searchCompletionCell = tableView.dequeueReusableCell(withIdentifier: SearchCompletionTableViewCell.identifier, for: indexPath) as! SearchCompletionTableViewCell

            // Get search result for the indexPath
            let searchCompletion = localSearchCompletionResults[indexPath.row]

            // Update the content
            searchCompletionCell.updateContent(searchCompletion: searchCompletion)

            cell = searchCompletionCell
        }

        cell.backgroundColor = .clear

        let selectedBackgroundView = UIView()
        selectedBackgroundView.backgroundColor = .gray.withAlphaComponent(0.2)
        cell.selectedBackgroundView = selectedBackgroundView

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if isRecentsShowing {
            searchBar.becomeFirstResponder()

            // Insert selected recent search to search bar
            let recentSearchText = RecentSearchesService.shared.recentSearches[indexPath.row]
            searchBar.text = recentSearchText
            searchBar.delegate?.searchBar?(searchBar, textDidChange: recentSearchText)

            // Add the recent search again to put it on top
            RecentSearchesService.shared.add(recentSearchText)
        } else {
            // Set selected search result
            selectedSearchCompletion = localSearchCompletionResults[indexPath.row]
        }

        // Deselect the row immediatly
        tableView.deselectRow(at: indexPath, animated: true)
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // If recent searches are showing, then user can edit the row
        isRecentsShowing
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            RecentSearchesService.shared.delete(at: indexPath.row)
        }

        tableView.reloadData()
    }
}
