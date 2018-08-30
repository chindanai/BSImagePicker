//
//  BSCustomCollectionViewCell.swift
//  BSImagePicker
//
//  Created by sakdanupong wiboonma on 30/8/2561 BE.
//

import UIKit

class BSCustomCollectionViewCell: UICollectionViewCell {
    
    weak var customView: UIView? {
        didSet {
            updateUI()
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    fileprivate func updateUI() {
        self.subviews.forEach({$0.removeFromSuperview()})

        
        if let customView = customView {
            customView.frame = CGRect(x: 0, y: 0, width: self.frame.size.width, height: self.frame.size.height)
            self.addSubview(customView)
            customView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        }
    }
}
