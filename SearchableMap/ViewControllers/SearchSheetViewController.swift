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
        tableView.register(SearchCompletionTableViewCell.self, forCellReuseIdentifier: SearchCompletionTableViewCell.identifier)

        return tableView
    }()
    private var isRecentsShowing: Bool {
        return if let text = searchBar.text {
            // If text is empty, recents will show
            text.isEmpty
        } else {
            // If text is nil, recents will show
            false
        }
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
            .sink { [weak self] completions in
                guard let self else { return }
                self.localSearchCompletionResults = completions
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
        let placeholderTexts = ["a restaurant", "a gas station", "a zoo", "a park", "a museum"]

        var iterator = placeholderTexts.makeIterator()
        let timer = Timer(timeInterval: 3, repeats: true) { timer in
            guard let text = self.searchBar.text, text.isEmpty else { return }

            if let text = iterator.next() {
                UIView.transition(with: self.searchBar, duration: 0.3, options: .transitionCrossDissolve) {
                    self.searchBar.placeholder = "Search \(text)"
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
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
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
        localSearchCompletionResults.count
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let label = UILabel()
        label.text = isRecentsShowing ? "Recents" : "Search Results"
        label.font = .preferredFont(forTextStyle: .callout, compatibleWith: UITraitCollection(legibilityWeight: .bold))
        label.textColor = .secondaryLabel

        let clearButton = UIButton(type: .system)
        clearButton.setTitle("Clear", for: .normal)
        //clearButton.addAction(  , for: .touchUpInside)
        clearButton.alpha = isRecentsShowing ? 1 : 0

        let stackView = UIStackView(arrangedSubviews: [label, clearButton])
        stackView.axis = .horizontal
        stackView.distribution = .fill

        stackView.layoutMargins = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10)
        stackView.isLayoutMarginsRelativeArrangement = true

        return stackView
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // Dequeue a cell from the pool
        let cell = tableView.dequeueReusableCell(withIdentifier: SearchCompletionTableViewCell.identifier, for: indexPath) as! SearchCompletionTableViewCell

        // Get search result for the indexPath
        let searchCompletion = localSearchCompletionResults[indexPath.row]

        // Update the content
        cell.updateContent(searchCompletion: searchCompletion)

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // Set selected row
        selectedSearchCompletion = localSearchCompletionResults[indexPath.row]

        // Deselect the row immediatly
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
