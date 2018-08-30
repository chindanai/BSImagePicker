//
//  BSCustomActionDataSource.swift
//  BSImagePicker
//
//  Created by sakdanupong wiboonma on 30/8/2561 BE.
//

import UIKit

class BSCustomActionDataSource: NSObject, UICollectionViewDataSource {
    let cellIdentifier = "bsCustomCellIdentifier"
    let settings: BSImagePickerSettings
    
    init(settings: BSImagePickerSettings) {
        self.settings = settings
        
        super.init()
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return ((settings.customActions?.count ?? 0) > 0) ? 1 : 0
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return settings.customActions?.count ?? 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let action = settings.customActions?[indexPath.item]
        let bsCustomCollectionViewCell = collectionView.dequeueReusableCell(withReuseIdentifier: cellIdentifier, for: indexPath) as! BSCustomCollectionViewCell
        bsCustomCollectionViewCell.accessibilityIdentifier = "bsCustomCollectionView_cell_\(indexPath.item)"
        bsCustomCollectionViewCell.customView = action?.view
        
        return bsCustomCollectionViewCell
    }
    
    func registerCellIdentifiersForCollectionView(_ collectionView: UICollectionView?) {
        collectionView?.register(BSCustomCollectionViewCell.self, forCellWithReuseIdentifier: cellIdentifier)
    }
}
