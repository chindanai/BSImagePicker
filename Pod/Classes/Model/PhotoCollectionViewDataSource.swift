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
        
        // Cancel any pending image requests
//        if cell.requestImageId != -1 {
//            photosManager.cancelImageRequest(PHImageRequestID(cell.requestImageId))
//        }

        
        let asset = assetAtIndexPath(indexPath)
        cell.asset = asset
        cell.assetId = asset.localIdentifier
        
        // Request image
        cell.requestImageId = Int(photosManager.requestImage(for: asset, targetSize: imageSize, contentMode: imageContentMode, options: nil) { (result, _) in
            DispatchQueue.main.async {
                if cell.assetId == asset.localIdentifier {
                    if let result = result {
                        cell.imageView.image = result
                    }
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
        let assets = indexPaths.map{assetAtIndexPath($0)}
        return assets
    }
    
    //MARK: - Asset Caching
    
    func stopCachedAssetes() {
        photosManager.stopCachingImagesForAllAssets()
        previousPreheatRect = CGRect.zero
    }
    
    func updateCachedAssets(_ collectionView: UICollectionView) {
        // The preheat window is twice the height of the visible rect.
        let visibleRect = CGRect(origin: collectionView.contentOffset, size: collectionView.bounds.size)
        let preheatRect = visibleRect.insetBy(dx: 0, dy: -0.5 * visibleRect.height)
        
        // Update only if the visible area is significantly different from the last preheated area.
        let delta = abs(preheatRect.midY - previousPreheatRect.midY)
        guard delta > UIScreen.main.bounds.size.height / 3 else { return }
        
        // Compute the assets to start caching and to stop caching.
        let (addedRects, removedRects) = differencesBetweenRects(previousPreheatRect, preheatRect)
        let addedAssets = addedRects
            .flatMap { rect in collectionView.indexPathsForElements(in: rect) }
            .map { indexPath in fetchResult.object(at: indexPath.item) }
        let removedAssets = removedRects
            .flatMap { rect in collectionView.indexPathsForElements(in: rect) }
            .map { indexPath in fetchResult.object(at: indexPath.item) }
        
        // Update the assets the PHCachingImageManager is caching.
        photosManager.startCachingImages(for: addedAssets,
                                        targetSize: imageSize, contentMode: imageContentMode, options: nil)
        photosManager.stopCachingImages(for: removedAssets,
                                       targetSize: imageSize, contentMode: imageContentMode, options: nil)
        
        // Store the preheat rect to compare against in the future.
        previousPreheatRect = preheatRect
    }
    
    fileprivate func differencesBetweenRects(_ old: CGRect, _ new: CGRect) -> (added: [CGRect], removed: [CGRect]) {
        if old.intersects(new) {
            var added = [CGRect]()
            if new.maxY > old.maxY {
                added += [CGRect(x: new.origin.x, y: old.maxY,
                                 width: new.width, height: new.maxY - old.maxY)]
            }
            if old.minY > new.minY {
                added += [CGRect(x: new.origin.x, y: new.minY,
                                 width: new.width, height: old.minY - new.minY)]
            }
            var removed = [CGRect]()
            if new.maxY < old.maxY {
                removed += [CGRect(x: new.origin.x, y: new.maxY,
                                   width: new.width, height: old.maxY - new.maxY)]
            }
            if old.minY < new.minY {
                removed += [CGRect(x: new.origin.x, y: old.minY,
                                   width: new.width, height: new.minY - old.minY)]
            }
            return (added, removed)
        } else {
            return ([new], [old])
        }
    }
}
