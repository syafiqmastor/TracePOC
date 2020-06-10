//
//  Nearby.swift
//  contacttracing
//
//  Created by Syafiq Mastor on 09/06/2020.
//  Copyright © 2020 syafiq. All rights reserved.
//

import Foundation
import UIKit

enum ConnectionType : String {
    case nearbyAPI = "Nearby API"
    case bluetooth = "Bluetooth"
    
    var title : String {
        return self.rawValue
    }
    
    var image : UIImage? {
        switch self {
        case .nearbyAPI:
            return UIImage(named: "google.jpg")
        case .bluetooth:
            return UIImage(named: "bluetooth")
        }
    }
}

class Nearby : Equatable {
    static func == (lhs: Nearby, rhs: Nearby) -> Bool {
        return lhs.date.compare(rhs.date) == .orderedSame
    }
    
    let type : String
    let title : String
    let date : Date
    let isBackground : Bool
    let multiplier : String
    let rssi : String
    
    init(type : String, title : String, date : Date, isBackground : Bool = false, multiplier : String, rssi : String) {
        self.type = type
        self.title = title
        self.date = date
        self.isBackground = isBackground
        self.multiplier = multiplier
        self.rssi = rssi
    }
    
    private var dateFormatter : DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm dd MMM yy"
        return formatter
    }()
    
    var dateString : String {
        return dateFormatter.string(from: date)
    }
}

