//
//  TurboBase.swift
//  Turbo Capture
//
//  Created by Shahan Khan on 9/8/14.
//  Copyright (c) 2014 Shahan Khan. All rights reserved.
//

import UIKit

class TurboBase: NSObject {
	// ensures handler function runs on the main thread
	internal func main(handler:()->()) {
		var thread = NSThread.currentThread()
		dispatch_async(dispatch_get_main_queue(), handler)
	}
}
