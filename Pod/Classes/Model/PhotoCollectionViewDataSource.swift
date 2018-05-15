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
    func indexPathForElementInRects(_ rect: CGRect) -> [IndexPath]? {
        let allLayoutAttributes = self.collectionViewLayout.layoutAttributesForElements(in: rect)
        
        var indexPaths: [IndexPath]?
        if let allLayoutAttributes = allLayoutAttributes, allLayoutAttributes.count > 0 {
            indexPaths = [IndexPath]()
            for layoutAttributes in allLayoutAttributes {
                let indexPath = layoutAttributes.indexPath
                indexPaths?.append(indexPath)
            }
        }
        
        return indexPaths
    }
}

final class PhotoCollectionViewDataSource : NSObject, UICollectionViewDataSource {
    var selections = [PHAsset]()
    var fetchResult: PHFetchResult<PHAsset>!

    fileprivate let photoCellIdentifier = "photoCellIdentifier"
    fileprivate let photosManager = PHCachingImageManager()
    fileprivate let imageContentMode: PHImageContentMode = .aspectFill
    
    var settings: BSImagePickerSettings?
    var imageSize: CGSize = CGSize.zero
    fileprivate var previousPreheatRect = CGRect.zero
    
    init(fetchResult: PHFetchResult<PHAsset>, selections: [PHAsset]? = nil, settings: BSImagePickerSettings?) {
        super.init()
        stopCachedAssetes()
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
        let asset = fetchResult[reversedIndex]
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
        
        // Cancel any pending image requests
        if cell.requestImageId != -1 {
            photosManager.cancelImageRequest(PHImageRequestID(cell.requestImageId))
        }

        
        let asset = assetAtIndexPath(indexPath)
        cell.asset = asset
        
        // Request image
        cell.requestImageId = Int(photosManager.requestImage(for: asset, targetSize: imageSize, contentMode: imageContentMode, options: nil) { (result, _) in
            if cell.asset?.localIdentifier == asset.localIdentifier {
                if let result = result {
                    cell.imageView.image = result
                }
            }
        })
        
        // Request Editing input
        
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
    
        
        // Request editing input
        // 2
//        if settings?.enableGif ?? false && selections.count == 0 {
//            let options = PHContentEditingInputRequestOptions()
//            options.isNetworkAccessAllowed = true
//            cell.editingInputId = asset.requestContentEditingInput(with: options) { (contentEditingInput, _) in
//                if let uniformTypeIdentifier = contentEditingInput?.uniformTypeIdentifier {
//                    if uniformTypeIdentifier == (kUTTypeGIF as String) {
//                        cell.hiddenGif = false
//                    }
//                }
//            }
//        }
        
        // 1
//         if settings?.enableGif ?? false && selections.count == 0 {
//            var isGif = false
//            DispatchQueue.global().async() {
//                let resourceList = PHAssetResource.assetResources(for: asset)
//                for (_, resource) in resourceList.enumerated() {
//                    if (resource.uniformTypeIdentifier == "com.compuserve.gif") {
//                        isGif = true
//                        break
//                    }
//                }
//                DispatchQueue.main.async() {
//                    cell.hiddenGif = !isGif
//                }
//            }
//         }
        
        UIView.setAnimationsEnabled(true)
        
        return cell
    }
    
    func registerCellIdentifiersForCollectionView(_ collectionView: UICollectionView?) {
        collectionView?.register(UINib(nibName: "PhotoCell", bundle: BSImagePickerViewController.bundle), forCellWithReuseIdentifier: photoCellIdentifier)
    }
    
    private func assetsAtIndexPaths(_ indexPaths: [IndexPath]) -> [PHAsset] {
        var assets = [PHAsset]()
        for indexPath in indexPaths {
            let asset = assetAtIndexPath(indexPath)
            assets.append(asset)
        }
        
        return assets
    }
    
    //MARK: - Asset Caching
    
    func stopCachedAssetes() {
        photosManager.stopCachingImagesForAllAssets()
        previousPreheatRect = CGRect.zero
    }
    
    func updateCachedAssets(_ collectionView: UICollectionView) {
        
        // The preheat window is twice the height of the visible rect.
        var preheatRect = collectionView.bounds
        preheatRect = preheatRect.insetBy(dx: 0.0, dy: -0.5 * preheatRect.size.height)
        
        /*
         Check if the collection view is showing an area that is significantly
         different to the last preheated area.
         */
        let delta = abs(preheatRect.midY - previousPreheatRect.midY)
        if delta > collectionView.bounds.size.height / 3.0 {
            
            // Compute the assets to start caching and to stop caching.
            var addedIndexPaths: [IndexPath] = []
            var removedIndexPaths: [IndexPath] = []
            
            self.computeDifferenceBetweenRect(self.previousPreheatRect, andRect: preheatRect, removedHandler: { removedRect in
                if let indexPaths = collectionView.indexPathForElementInRects(removedRect) {
                    removedIndexPaths += indexPaths
                }
            }, addedHandler: { addedRect in
                if let indexPaths = collectionView.indexPathForElementInRects(addedRect) {
                    addedIndexPaths += indexPaths
                }
            })
            
            let assetsToStartCaching = self.assetsAtIndexPaths(addedIndexPaths)
            let assetsToStopCaching = self.assetsAtIndexPaths(removedIndexPaths)
            
            // Update the assets the PHCachingImageManager is caching.
            photosManager.startCachingImages(for: assetsToStartCaching, targetSize: imageSize, contentMode: imageContentMode, options: nil)
            photosManager.stopCachingImages(for: assetsToStopCaching, targetSize: imageSize, contentMode: imageContentMode, options: nil)
            
            // Store the preheat rect to compare against in the future.
            self.previousPreheatRect = preheatRect
        }
    }
    
    private func computeDifferenceBetweenRect(_ oldRect: CGRect, andRect newRect: CGRect, removedHandler: (CGRect)->Void, addedHandler: (CGRect)->Void) {
        
        if newRect.intersects(oldRect) {
            let oldMaxY = oldRect.maxY
            let oldMinY = oldRect.minY
            let newMaxY = newRect.maxY
            let newMinY = newRect.minY
            
            if newMaxY > oldMaxY {
                let rectToAdd = CGRect(x: newRect.origin.x, y: oldMaxY, width: newRect.size.width, height: (newMaxY - oldMaxY))
                addedHandler(rectToAdd)
            }
            
            if oldMinY > newMinY {
                let rectToAdd = CGRect(x: newRect.origin.x, y: newMinY, width: newRect.size.width, height: (oldMinY - newMinY))
                addedHandler(rectToAdd)
            }
            
            if newMaxY < oldMaxY {
                let rectToRemove = CGRect(x: newRect.origin.x, y: newMaxY, width: newRect.size.width, height: (oldMaxY - newMaxY))
                removedHandler(rectToRemove)
            }
            
            if oldMinY < newMinY {
                let rectToRemove = CGRect(x: newRect.origin.x, y: oldMinY, width: newRect.size.width, height: (newMinY - oldMinY))
                removedHandler(rectToRemove)
            }
        } else {
            addedHandler(newRect)
            removedHandler(oldRect)
        }
    }
}
