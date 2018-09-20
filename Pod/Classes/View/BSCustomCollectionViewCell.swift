//
//  BSCustomCollectionViewCell.swift
//  BSImagePicker
//
//  Created by sakdanupong wiboonma on 30/8/2561 BE.
//

import UIKit

class BSCustomCollectionViewCell: UICollectionViewCell {
    
    var customView: UIView? {
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
            customView.frame = CGRect.zero
            self.addSubview(customView)
            
            setNeedsLayout()
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
    
        if !self.frame.size.width.isNaN && !self.frame.size.height.isNaN {
            customView?.frame = CGRect(x: 0, y: 0, width: self.frame.size.width, height: self.frame.size.height)
        }
    }
}
