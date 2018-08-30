//
//  CustomView.swift
//  BSImagePicker_Example
//
//  Created by sakdanupong wiboonma on 30/8/2561 BE.
//  Copyright © 2561 CocoaPods. All rights reserved.
//

import UIKit

class CustomView: UIView {
    
    static func instanceView() -> CustomView {
        let customView = UINib(nibName: "CustomView", bundle: nil).instantiate(withOwner: nil, options: nil)[0] as! CustomView
        return customView
    }
    
    @IBOutlet fileprivate weak var titleLabel: UILabel!
    
    var titleText: String? {
        didSet {
            updateUI()
        }
    }
    
    fileprivate func updateUI() {
        titleLabel.text = titleText
    }
}
