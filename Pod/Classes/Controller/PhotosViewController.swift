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
import BSGridCollectionViewLayout
fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}

fileprivate func > <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l > r
  default:
    return rhs < lhs
  }
}


final class PhotosViewController : UICollectionViewController {    
    var selectionClosure: ((_ asset: PHAsset) -> Void)?
    var deselectionClosure: ((_ asset: PHAsset) -> Void)?
    var cancelClosure: ((_ assets: [PHAsset]) -> Void)?
    var finishClosure: ((_ assets: [PHAsset]) -> Void)?
    var finishWithGifClosure: ((_ assets: [PHAsset]) -> Void)?
    
    var doneBarButton: UIBarButtonItem?
    var cancelBarButton: UIBarButtonItem?
    var albumTitleView: AlbumTitleView?
    
    let expandAnimator = ZoomAnimator()
    let shrinkAnimator = ZoomAnimator()
    
    fileprivate var photosDataSource: PhotoCollectionViewDataSource?
    fileprivate var albumsDataSource: AlbumTableViewDataSource?
    fileprivate let cameraDataSource: CameraCollectionViewDataSource
    fileprivate var composedDataSource: ComposedCollectionViewDataSource?
    
    fileprivate var defaultSelections: [PHAsset]?
    fileprivate var filteredResults: PHFetchResult<PHAsset>?
    
    let settings: BSImagePickerSettings
    
    fileprivate var doneBarButtonTitle: String?
    
    lazy var albumsViewController: AlbumsViewController = {
        let storyboard = UIStoryboard(name: "Albums", bundle: BSImagePickerViewController.bundle)
        let vc = storyboard.instantiateInitialViewController() as! AlbumsViewController
        vc.tableView.dataSource = self.albumsDataSource
        vc.tableView.delegate = self
        
        return vc
    }()
    
    fileprivate lazy var previewViewContoller: PreviewViewController? = {
        return PreviewViewController(nibName: nil, bundle: nil)
    }()
    
    required init(fetchResults: [PHFetchResult<PHAssetCollection>], defaultSelections: [PHAsset]? = nil, settings aSettings: BSImagePickerSettings) {
        albumsDataSource = AlbumTableViewDataSource(fetchResults: fetchResults)
        cameraDataSource = CameraCollectionViewDataSource(settings: aSettings, cameraAvailable: UIImagePickerController.isSourceTypeAvailable(.camera))
        self.defaultSelections = defaultSelections
        settings = aSettings
        
        super.init(collectionViewLayout: GridCollectionViewLayout())
        
        PHPhotoLibrary.shared().register(self)
    }
    
    required init(filteredResults: PHFetchResult<PHAsset>, defaultSelections: [PHAsset]? = nil, settings aSettings: BSImagePickerSettings) {
        cameraDataSource = CameraCollectionViewDataSource(settings: aSettings, cameraAvailable: UIImagePickerController.isSourceTypeAvailable(.camera))
        self.filteredResults = filteredResults
        self.defaultSelections = defaultSelections
        settings = aSettings
        
        super.init(collectionViewLayout: GridCollectionViewLayout())
        
        PHPhotoLibrary.shared().register(self)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("b0rk: initWithCoder not implemented")
    }
    
    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }
    
    override func loadView() {
        super.loadView()
        
        // Setup collection view
        collectionView?.backgroundColor = settings.backgroundColor
        collectionView?.allowsMultipleSelection = true
        
        // Set an empty title to get < back button
        title = " "
        
        // Set button actions and add them to navigation item
        doneBarButton?.target = self
        doneBarButton?.action = #selector(PhotosViewController.doneButtonPressed(_:))
        cancelBarButton?.target = self
        cancelBarButton?.action = #selector(PhotosViewController.cancelButtonPressed(_:))
        albumTitleView?.albumButton?.addTarget(self, action: #selector(PhotosViewController.albumButtonPressed(_:)), for: .touchUpInside)
        navigationItem.leftBarButtonItem = cancelBarButton
        navigationItem.rightBarButtonItem = doneBarButton
        navigationItem.titleView = albumTitleView

        if let album = albumsDataSource?.fetchResults.first?.firstObject {
            initializePhotosDataSource(album, selections: defaultSelections)
            updateAlbumTitle(album)
        } else if let filteredResults = self.filteredResults {
            initializePhotosDataSourceWithFetchResult(filteredResults)
        }
        collectionView?.reloadData()
        
        // Add long press recognizer
        let longPressRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(PhotosViewController.collectionViewLongPressed(_:)))
        longPressRecognizer.minimumPressDuration = 0.5
        collectionView?.addGestureRecognizer(longPressRecognizer)
        
        // Set navigation controller delegate
        navigationController?.delegate = self
        
        // Register cells
        photosDataSource?.registerCellIdentifiersForCollectionView(collectionView)
        cameraDataSource.registerCellIdentifiersForCollectionView(collectionView)
    }
    
    // MARK: Appear/Disappear
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        updateDoneButton()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if let collectionView = collectionView {
            photosDataSource?.updateCachedAssets(collectionView)
        }
    }
    
    // MARK: Button actions
    func cancelButtonPressed(_ sender: UIBarButtonItem) {
        guard let closure = cancelClosure, let photosDataSource = photosDataSource else {
            dismiss(animated: true, completion: nil)
            return
        }
        DispatchQueue.global().async {
            closure(photosDataSource.selections)
        }
        
        dismiss(animated: true, completion: nil)
    }
    
    func doneButtonPressed(_ sender: UIBarButtonItem) {
        guard let photosDataSource = photosDataSource else {
            dismiss(animated: true, completion: nil)
            return
        }
        
        finishWithAssets(photosDataSource.selections)
    }
    
    func albumButtonPressed(_ sender: UIButton) {
        guard let popVC = albumsViewController.popoverPresentationController else {
            return
        }
        
        popVC.permittedArrowDirections = .up
        popVC.sourceView = sender
        let senderRect = sender.convert(sender.frame, from: sender.superview)
        let sourceRect = CGRect(x: senderRect.origin.x, y: senderRect.origin.y + (sender.frame.size.height / 2), width: senderRect.size.width, height: senderRect.size.height)
        popVC.sourceRect = sourceRect
        popVC.delegate = self
        albumsViewController.tableView.reloadData()
        
        present(albumsViewController, animated: true, completion: nil)
    }
    
    func collectionViewLongPressed(_ sender: UIGestureRecognizer) {
        if sender.state == .began {
            // Disable recognizer while we are figuring out location and pushing preview
            sender.isEnabled = false
            collectionView?.isUserInteractionEnabled = false
            
            // Calculate which index path long press came from
            let location = sender.location(in: collectionView)
            let indexPath = collectionView?.indexPathForItem(at: location)
            
            if let vc = previewViewContoller, let indexPath = indexPath, let cell = collectionView?.cellForItem(at: indexPath) as? PhotoCell, let asset = cell.asset {
                // Setup fetch options to be synchronous
                let options = PHImageRequestOptions()
                options.isSynchronous = true
                
                // Load image for preview
                if let imageView = vc.imageView {
                    PHCachingImageManager.default().requestImage(for: asset, targetSize:PHImageManagerMaximumSize, contentMode: .aspectFit, options: options) { (result, _) in
                        imageView.image = result
                    }
                }
                
                // Setup animation
                expandAnimator.sourceImageView = cell.imageView
                expandAnimator.destinationImageView = vc.imageView
                shrinkAnimator.sourceImageView = vc.imageView
                shrinkAnimator.destinationImageView = cell.imageView
                
                navigationController?.pushViewController(vc, animated: true)
            }
            
            // Re-enable recognizer, after animation is done
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(expandAnimator.transitionDuration(using: nil) * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC), execute: { () -> Void in
                sender.isEnabled = true
                self.collectionView?.isUserInteractionEnabled = true
            })
        }
    }
    
    // MARK: Private helper methods
    func updateDoneButton() {
        // Find right button
        if #available(iOS 11.0, *) {
            guard let photosDataSource = photosDataSource else {
                return
            }
            
            if doneBarButtonTitle == nil {
                doneBarButtonTitle = "Done"
            }
            
            let btn = UIButton(type: .custom)
            btn.addTarget(self, action: #selector(PhotosViewController.doneButtonPressed(_:)), for: .touchUpInside)
            btn.setTitle(doneBarButtonTitle, for: .normal)
            btn.setTitleColor(navigationController?.navigationBar.tintColor ?? UIColor.red, for: .normal)
            btn.setTitleColor(UIColor.lightGray, for: .disabled)
            
            let tempDoneButtonItem = UIBarButtonItem(customView: btn)
            self.navigationItem.rightBarButtonItem = tempDoneButtonItem
            
            doneBarButton = tempDoneButtonItem
            
            if (photosDataSource.selections.count == 1 && self.settings.maxNumberOfSelections == 1) {
                btn.bs_setTitleWithoutAnimation("\(doneBarButtonTitle ?? "Done")", forState: UIControlState())
            } else if photosDataSource.selections.count > 0 {
                btn.bs_setTitleWithoutAnimation("\(doneBarButtonTitle ?? "Done") (\(photosDataSource.selections.count))", forState: UIControlState())
            } else {
                btn.bs_setTitleWithoutAnimation(doneBarButtonTitle, forState: UIControlState())
            }
            
            // Enabled?
            btn.isEnabled = photosDataSource.selections.count > 0
        } else {
            if let subViews = navigationController?.navigationBar.subviews, let photosDataSource = photosDataSource {
                for view in subViews {
                    if let btn = view as? UIButton , checkIfRightButtonItem(btn) {
                        // Store original title if we havn't got it
                        if doneBarButtonTitle == nil {
                            doneBarButtonTitle = btn.title(for: UIControlState())
                        }
                        
                        // Update title
                        if let doneBarButtonTitle = doneBarButtonTitle {
                            // Special case if we have selected 1 image and that is
                            // the max number of allowed selections
                            if (photosDataSource.selections.count == 1 && self.settings.maxNumberOfSelections == 1) {
                                btn.bs_setTitleWithoutAnimation("\(doneBarButtonTitle)", forState: UIControlState())
                            } else if photosDataSource.selections.count > 0 {
                                btn.bs_setTitleWithoutAnimation("\(doneBarButtonTitle) (\(photosDataSource.selections.count))", forState: UIControlState())
                            } else {
                                btn.bs_setTitleWithoutAnimation(doneBarButtonTitle, forState: UIControlState())
                            }
                            
                            // Enabled?
                            doneBarButton?.isEnabled = photosDataSource.selections.count > 0
                        }
                        
                        // Stop loop
                        break
                    }
                }
            }
            
        }
        
        self.navigationController?.navigationBar.setNeedsLayout()
    }
    
    // Check if a give UIButton is the right UIBarButtonItem in the navigation bar
    // Somewhere along the road, our UIBarButtonItem gets transformed to an UINavigationButton
    func checkIfRightButtonItem(_ btn: UIButton) -> Bool {
        guard let rightButton = navigationItem.rightBarButtonItem else {
            return false
        }
        
        // Store previous values
        let wasRightEnabled = rightButton.isEnabled
        let wasButtonEnabled = btn.isEnabled
        
        // Set a known state for both buttons
        rightButton.isEnabled = false
        btn.isEnabled = false
        
        // Change one and see if other also changes
        rightButton.isEnabled = true
        let isRightButton = btn.isEnabled
        
        // Reset
        rightButton.isEnabled = wasRightEnabled
        btn.isEnabled = wasButtonEnabled
        
        return isRightButton
    }
    
    func updateAlbumTitle(_ album: PHAssetCollection) {
        if let title = album.localizedTitle {
            // Update album title
            albumTitleView?.albumTitle = title
        }
    }
    
  func initializePhotosDataSource(_ album: PHAssetCollection, selections: [PHAsset]? = nil) {
        // Set up a photo data source with album
        let fetchOptions = PHFetchOptions()
//         fetchOptions.sortDescriptors = [
//             NSSortDescriptor(key: "creationDate", ascending: false)
//         ]
        fetchOptions.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)
        initializePhotosDataSourceWithFetchResult(PHAsset.fetchAssets(in: album, options: fetchOptions), selections: selections)
    }
    
    func initializePhotosDataSourceWithFetchResult(_ fetchResult: PHFetchResult<PHAsset>, selections: [PHAsset]? = nil) {
        let newDataSource = PhotoCollectionViewDataSource(fetchResult: fetchResult, selections: selections, settings: settings)
        
        // Transfer image size
        // TODO: Move image size to settings
        if let photosDataSource = photosDataSource {
            newDataSource.imageSize = photosDataSource.imageSize
            newDataSource.selections = photosDataSource.selections
        }
        
        photosDataSource = newDataSource
        
        // Hook up data source
        composedDataSource = ComposedCollectionViewDataSource(dataSources: [cameraDataSource, newDataSource])
        collectionView?.dataSource = composedDataSource
        collectionView?.delegate = self
    }
}

// MARK: UICollectionViewDelegate
extension PhotosViewController {
    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard self.isViewLoaded && self.view.window != nil else {
            return
        }
        
        if let collectionView = collectionView {
            photosDataSource?.updateCachedAssets(collectionView)
        }
    }
    
    override func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        // NOTE: ALWAYS return false. We don't want the collectionView to be the source of thruth regarding selections
        // We can manage it ourself.

        // Camera shouldn't be selected, but pop the UIImagePickerController!
        if let composedDataSource = composedDataSource , composedDataSource.dataSources[indexPath.section].isEqual(cameraDataSource) {
            let cameraController = UIImagePickerController()
            cameraController.allowsEditing = false
            cameraController.sourceType = .camera
            cameraController.delegate = self
            
            self.present(cameraController, animated: true, completion: nil)
            
            return false
        }

        // Make sure we have a data source and that we can make selections
        guard let photosDataSource = photosDataSource, collectionView.isUserInteractionEnabled else { return false }

        // We need a cell
        guard let cell = collectionView.cellForItem(at: indexPath) as? PhotoCell else { return false }
        let asset = photosDataSource.assetAtIndexPath(indexPath)

        // Select or deselect?
        if let index = photosDataSource.selections.index(of: asset) { // Deselect
            // Deselect asset
            photosDataSource.selections.remove(at: index)

            // Update done button
            updateDoneButton()

            // Get indexPaths of selected items
            let selectedIndexPaths = photosDataSource.selections.flatMap({ (asset) -> IndexPath? in
                let index = photosDataSource.fetchResult.index(of: asset)
                guard index != NSNotFound else { return nil }
                return IndexPath(item: index, section: 1)
            })

            // Reload selected cells to update their selection number
            UIView.setAnimationsEnabled(false)
            collectionView.reloadItems(at: selectedIndexPaths)
            UIView.setAnimationsEnabled(true)

            cell.photoSelected = false

            if settings.enableGif && photosDataSource.selections.count == 0 {
                enableGif()
            }
            
            // Call deselection closure
            if let closure = deselectionClosure {
                DispatchQueue.global().async {
                    closure(asset)
                }
            }
        } else if photosDataSource.selections.count < settings.maxNumberOfSelections { // Select
            // Select asset if not already selected
            photosDataSource.selections.append(asset)
            
            if settings.multipleSelectionMode {
                // Set selection number
                if let selectionCharacter = settings.selectionCharacter {
                    cell.selectionString = String(selectionCharacter)
                } else {
                    cell.selectionString = String(photosDataSource.selections.count)
                }
                
                cell.photoSelected = true
                
                // Update done button
                updateDoneButton()
                
                if settings.enableGif {
                    if photosDataSource.selections.count == 1 && asset.isGif() {
                        showDisplayGifOrImageOptions(asset)
                    } else {
                        selectAssetAsImage(asset)
                    }
                } else {
                    selectAssetAsImage(asset)
                }
            } else {
                if settings.enableGif && asset.isGif() {
                    finishWithSelectGif(asset)
                } else {
                    finishWithAssets([asset])
                }
            }
        }

        return false
    }
    
    override func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let cell = cell as? CameraCell else {
            return
        }
        
        cell.startLiveBackground() // Start live background
    }
}

// MARK: UIPopoverPresentationControllerDelegate
extension PhotosViewController: UIPopoverPresentationControllerDelegate {
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
    }
    
    func popoverPresentationControllerShouldDismissPopover(_ popoverPresentationController: UIPopoverPresentationController) -> Bool {
        return true
    }
}
// MARK: UINavigationControllerDelegate
extension PhotosViewController: UINavigationControllerDelegate {
    func navigationController(_ navigationController: UINavigationController, animationControllerFor operation: UINavigationControllerOperation, from fromVC: UIViewController, to toVC: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        if operation == .push {
            return expandAnimator
        } else {
            return shrinkAnimator
        }
    }
}

// MARK: UITableViewDelegate
extension PhotosViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // Update photos data source
        if let album = albumsDataSource?.fetchResults[indexPath.section][indexPath.row] {
            initializePhotosDataSource(album)
            updateAlbumTitle(album)
            collectionView?.reloadData()
            
            // Dismiss album selection
            albumsViewController.dismiss(animated: true, completion: nil)
        }
    }
}

// MARK: Traits
extension PhotosViewController {
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        if let collectionViewFlowLayout = collectionViewLayout as? GridCollectionViewLayout {
            let itemSpacing: CGFloat = 2.0
            let cellsPerRow = settings.cellsPerRow(traitCollection.verticalSizeClass, traitCollection.horizontalSizeClass)
            
            collectionViewFlowLayout.itemSpacing = itemSpacing
            collectionViewFlowLayout.itemsPerRow = cellsPerRow
            
            let imageSize = collectionViewFlowLayout.itemSize
            let retinaScale = (PHImageManagerMaximumSize.equalTo(imageSize)) ? 1 :  UIScreen.main.scale
            let retinaSize = CGSize(width: imageSize.width * retinaScale, height: imageSize.height * retinaScale)
            photosDataSource?.imageSize = retinaSize
            
            updateDoneButton()
        }
    }
}

// MARK: UIImagePickerControllerDelegate
extension PhotosViewController: UIImagePickerControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        guard let image = info[UIImagePickerControllerOriginalImage] as? UIImage else {
            picker.dismiss(animated: true, completion: nil)
            return
        }
        
        var placeholder: PHObjectPlaceholder?
        PHPhotoLibrary.shared().performChanges({
            let request = PHAssetChangeRequest.creationRequestForAsset(from: image)
            placeholder = request.placeholderForCreatedAsset
            }, completionHandler: { success, error in
                guard let placeholder = placeholder, let asset = PHAsset.fetchAssets(withLocalIdentifiers: [placeholder.localIdentifier], options: nil).firstObject, success == true else {
                    picker.dismiss(animated: true, completion: nil)
                    return
                }
                
                DispatchQueue.main.async {
                    // TODO: move to a function. this is duplicated in didSelect
                    self.photosDataSource?.selections.append(asset)
                    self.updateDoneButton()
                    
                    // Call selection closure
                    if let closure = self.selectionClosure {
                        DispatchQueue.global().async {
                            closure(asset)
                        }
                    }
                    
                    picker.dismiss(animated: true, completion: nil)
                }
        })
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
}

// MARK: PHPhotoLibraryChangeObserver
extension PhotosViewController: PHPhotoLibraryChangeObserver {
    func photoLibraryDidChange(_ changeInstance: PHChange) {
        guard let photosDataSource = photosDataSource, let collectionView = collectionView else {
            return
        }
        
        DispatchQueue.main.async(execute: { () -> Void in
            if let photosChanges = changeInstance.changeDetails(for: photosDataSource.fetchResult as! PHFetchResult<PHObject>) {
                // Update collection view
                // Alright...we get spammed with change notifications, even when there are none. So guard against it
                if photosChanges.hasIncrementalChanges && (photosChanges.removedIndexes?.count > 0 || photosChanges.insertedIndexes?.count > 0 || photosChanges.changedIndexes?.count > 0) {
                    // Update fetch result
                    photosDataSource.fetchResult = photosChanges.fetchResultAfterChanges as! PHFetchResult<PHAsset>
                    
                    //if let removed = photosChanges.removedIndexes {
                    //    collectionView.deleteItems(at: removed.sdnp_indexPathsForSection(1, fetchResult: photosDataSource.fetchResult))
                    //}
                    
                    //if let inserted = photosChanges.insertedIndexes {
                    //    collectionView.insertItems(at: inserted.sdnp_indexPathsForSection(1, fetchResult: photosDataSource.fetchResult))
                    //}
                    
                    // Changes is causing issues right now...fix me later
                    // Example of issue:
                    // 1. Take a new photo
                    // 2. We will get a change telling to insert that asset
                    // 3. While it's being inserted we get a bunch of change request for that same asset
                    // 4. It flickers when reloading it while being inserted
                    // TODO: FIX
                    //                    if let changed = photosChanges.changedIndexes {
                    //                        print("changed")
                    //                        collectionView.reloadItemsAtIndexPaths(changed.bs_indexPathsForSection(1))
                    //                    }
                    
                    // Reload view
                    collectionView.reloadData()
                    photosDataSource.stopCachedAssetes()
                } else if photosChanges.hasIncrementalChanges == false {
                    // Update fetch result
                    photosDataSource.fetchResult = photosChanges.fetchResultAfterChanges as! PHFetchResult<PHAsset>
                    
                    // Reload view
                    collectionView.reloadData()
                    photosDataSource.stopCachedAssetes()
                }
            }
        })
        
        
        // TODO: Changes in albums
    }
}

// Mod's Code
extension PhotosViewController {
    fileprivate func showDisplayGifOrImageOptions(_ asset: PHAsset) {
        let alertController = UIAlertController(title: "", message: "Do you want to display this image as GIF?", preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: .default) { [weak self] (action) in
            self?.finishWithSelectGif(asset)
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { [weak self] (action) in
            self?.selectAssetAsImage(asset)
        }
        
        alertController.addAction(okAction)
        alertController.addAction(cancelAction)

        present(alertController, animated: true, completion: nil)
    }
    
    fileprivate func disableGif() {
        if let collectionView = collectionView {
            
            for cell in collectionView.visibleCells {
                let photoCell = cell as? PhotoCell
                photoCell?.hiddenGif = true
            }
        }
    }
    
    fileprivate func enableGif() {
        if let collectionView = collectionView {
            for cell in collectionView.visibleCells {
                let photoCell = cell as? PhotoCell
                photoCell?.hiddenGif = !(photoCell?.asset?.isGif() ?? false)
            }
        }
    }
    
    fileprivate func selectAssetAsImage(_ asset: PHAsset) {
        if let closure = selectionClosure {
            DispatchQueue.global().async {
                closure(asset)
            }
        }
        
        if settings.enableGif {
            disableGif()
        }
    }
    
    fileprivate func finishWithSelectGif(_ asset: PHAsset) {
        guard let closure = finishWithGifClosure else {
            dismiss(animated: true, completion: nil)
            return
        }
        
        DispatchQueue.global().async {
            closure([asset])
        }
        
        dismiss(animated: true, completion: nil)
    }
    
    fileprivate func finishWithAssets(_ assets: [PHAsset]) {
        guard let closure = finishClosure else {
            if (settings.dismissWhenFinished) {
                dismiss(animated: true, completion: nil)
            }
            return
        }
        
        DispatchQueue.global().async {
            closure(assets)
        }
        
        if (settings.dismissWhenFinished) {
            dismiss(animated: true, completion: nil)
        }
    }
}
