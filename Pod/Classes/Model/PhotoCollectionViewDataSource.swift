// The MIT License (MIT)
//
// Copyright (c) 2015 Joakim Gyllström
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import UIKit
import Photos
import MobileCoreServices

/**
Gives UICollectionViewDataSource functionality with a given data source and cell factory
*/

extension UICollectionView {
    func indexPathsForElements(in rect: CGRect) -> [IndexPath] {
        let allLayoutAttributes = collectionViewLayout.layoutAttributesForElements(in: rect)!
        return allLayoutAttributes.map { $0.indexPath }
    }
}

final class PhotoCollectionViewDataSource : NSObject, UICollectionViewDataSource {
    var selections = [PHAsset]()
    var fetchResult: PHFetchResult<PHAsset>!

    fileprivate let photoCellIdentifier = "photoCellIdentifier"
    fileprivate let photosManager = PHCachingImageManager()
    fileprivate let manager = PHImageManager.default()
    fileprivate let imageContentMode: PHImageContentMode = .aspectFill
    
    var settings: BSImagePickerSettings?
    var imageSize: CGSize = CGSize.zero
    
    init(fetchResult: PHFetchResult<PHAsset>, selections: [PHAsset]? = nil, settings: BSImagePickerSettings?) {
        super.init()

        self.initFetchResult(fetchResult)
        self.settings = settings
        if let selections = selections {
            self.selections = selections
        }
    }
    
    fileprivate func initFetchResult(_ fetchResult: PHFetchResult<PHAsset>) {
        self.fetchResult = fetchResult
    }
    
    func assetAtIndexPath(_ indexPath: IndexPath) -> PHAsset {
        let reversedIndex = fetchResult.count - indexPath.item - 1
        let asset = fetchResult.object(at: reversedIndex)
        return asset
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return fetchResult.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        UIView.setAnimationsEnabled(false)
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: photoCellIdentifier, for: indexPath) as! PhotoCell
        cell.accessibilityIdentifier = "photo_cell_\(indexPath.item)"
        if let settings = settings {
            cell.settings = settings
        }
        
        let asset = assetAtIndexPath(indexPath)
        cell.asset = asset
        cell.assetId = asset.localIdentifier
        
        // Request image
        photosManager.requestImage(for: asset, targetSize: imageSize, contentMode: imageContentMode, options: nil) { (result, _) in
            DispatchQueue.main.async {
                if cell.assetId == asset.localIdentifier {
                    if let result = result {
                        cell.imageView.image = result
                    }
                }
            }
        }
        
        // Set selection number
        if let index = selections.index(of: asset) {
            if let character = settings?.selectionCharacter {
                cell.selectionString = String(character)
            } else {
                cell.selectionString = String(index+1)
            }
            
            cell.photoSelected = true
        } else {
            cell.photoSelected = false
        }
        
         cell.hiddenGif = true
        
        // 3
        if settings?.enableGif ?? false && selections.count == 0 {
            if let identifier = asset.value(forKey: "uniformTypeIdentifier") as? String {
                if identifier == kUTTypeGIF as String {
                    cell.hiddenGif = false
                }
            }
        }
        
        UIView.setAnimationsEnabled(true)
        
        return cell
    }
    
    func registerCellIdentifiersForCollectionView(_ collectionView: UICollectionView?) {
        collectionView?.register(UINib(nibName: "PhotoCell", bundle: BSImagePickerViewController.bundle), forCellWithReuseIdentifier: photoCellIdentifier)
    }
    
    private func assetsAtIndexPaths(_ indexPaths: [IndexPath]) -> [PHAsset] {
        let assets = indexPaths.map{assetAtIndexPath($0)}
        return assets
    }
}
