//
//  PHAsset+GIF.swift
//  BSImagePicker
//
//  Created by Sakdanupong Wiboonma on 9/24/2560 BE.
//

import Photos

extension PHAsset {
    
    func isGif() -> Bool {
        var isGif = false
        let phAssetResources = PHAssetResource.assetResources(for: self)
        for phAssetResource in phAssetResources {
            if (phAssetResource.uniformTypeIdentifier == "com.compuserve.gif") {
                isGif = true
                break
            }
        }
        
        return isGif
    }
}
