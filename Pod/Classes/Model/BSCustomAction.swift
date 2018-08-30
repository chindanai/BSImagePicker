//
//  BSCustomAction.swift
//  BSImagePicker
//
//  Created by sakdanupong wiboonma on 30/8/2561 BE.
//

import UIKit

public class BSCustomAction: NSObject {
    public var view: UIView?
    public var action: ((_ bsImagePickerViewController: UINavigationController?)->())?
}


