//
//  UIFont+withWeight.swift
//  SearchableMap
//
//  Created by İbrahim Çetin on 7.06.2024.
//

import UIKit

extension UIFont {
    func withWeight(_ weight: UIFont.Weight) -> UIFont {
        let descriptor = self.fontDescriptor.addingAttributes([
            .traits: [UIFontDescriptor.TraitKey.weight: weight]
        ])
        return UIFont(descriptor: descriptor, size: 0)
    }
}
