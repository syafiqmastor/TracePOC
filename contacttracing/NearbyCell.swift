//
//  NearbyCell.swift
//  contacttracing
//
//  Created by Syafiq Mastor on 09/06/2020.
//  Copyright © 2020 syafiq. All rights reserved.
//

import UIKit

class NearbyCell: UITableViewCell {

    @IBOutlet weak var typeLabel: UILabel!
    @IBOutlet weak var deviceNameLabel: UILabel!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var typeImageView: UIImageView!
    @IBOutlet weak var rssiLabel: UILabel!
    @IBOutlet weak var mutliLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    func add(nearby : Nearby) {
        typeLabel.text = nearby.type
        deviceNameLabel.text = nearby.title
        timeLabel.text = nearby.dateString
        rssiLabel.text = nearby.rssi
        mutliLabel.text = nearby.multiplier
        
        switch nearby.type.lowercased() {
        case "Nearby API".lowercased():
            typeImageView.image = UIImage(named: "google.jpg")
            self.backgroundColor = UIColor.yellow
        case "Bluetooth".lowercased():
            self.backgroundColor = UIColor.white
            typeImageView.image = UIImage(named: "bluetooth")
        default:
            self.backgroundColor = UIColor.white
            typeImageView.image = nil
        }

    }
    
}
