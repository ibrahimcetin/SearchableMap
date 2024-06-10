//
//  CLLocationCoordinate2D+Equatable.swift
//  SearchableMap
//
//  Created by İbrahim Çetin on 7.06.2024.
//

import CoreLocation

extension CLLocationCoordinate2D: Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}
