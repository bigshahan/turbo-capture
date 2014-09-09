//
//  TurboBase.swift
//  Turbo Capture
//
//  Created by Shahan Khan on 9/8/14.
//  Copyright (c) 2014 Shahan Khan. All rights reserved.
//

import UIKit

class TurboBase: NSObject {
	internal func main(handler:()->()) {
		dispatch_async(dispatch_get_main_queue(), handler)
	}
}
