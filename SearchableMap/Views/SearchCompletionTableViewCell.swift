//
//  SearchCompletionTableViewCell.swift
//  SearchableMap
//
//  Created by İbrahim Çetin on 9.06.2024.
//

import UIKit
import MapKit

class SearchCompletionTableViewCell: UITableViewCell {
    static let identifier = "SearchCompletionTableViewCell"

    func updateContent(searchCompletion: MKLocalSearchCompletion) {
        var configuration = self.defaultContentConfiguration()

        configuration.textProperties.font = .preferredFont(forTextStyle: .headline)
        configuration.attributedText = createAttributedText(
            text: searchCompletion.title,
            font: configuration.textProperties.font,
            ranges: searchCompletion.titleHighlightRanges
        )

        configuration.secondaryTextProperties.font = .preferredFont(forTextStyle: .subheadline)
        configuration.secondaryAttributedText = createAttributedText(
            text: searchCompletion.subtitle,
            font: configuration.secondaryTextProperties.font,
            ranges: searchCompletion.subtitleHighlightRanges
        )

        // Update cell properties
        self.contentConfiguration = configuration
    }

    private func createAttributedText(text: String, font: UIFont, ranges: [NSValue]) -> NSAttributedString {
        let string = NSMutableAttributedString(string: text)

        let ranges = ranges.map { $0.rangeValue }
        for range in ranges {
            string.addAttribute(.font, value: font.withWeight(.regular), range: range)
        }

        return string
    }
}
