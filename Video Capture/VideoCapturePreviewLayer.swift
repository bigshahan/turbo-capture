//
//  VideoCaptureLayer.swift
//  Video Capture
//
//  Created by Shahan Khan on 9/5/14.
//  Copyright (c) 2014 Shahan Khan
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//	of this software and associated documentation files (the "Software"), to deal
//	in the Software without restriction, including without limitation the rights
//	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//	copies of the Software, and to permit persons to whom the Software is
//	furnished to do so, subject to the following conditions:
//
//	The above copyright notice and this permission notice shall be included in
//	all copies or substantial portions of the Software.
//
//	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//	THE SOFTWARE.

import AVFoundation
import UIKit

class VideoCapturePreviewLayer: AVCaptureVideoPreviewLayer {
	init(view: UIView) {
		super.init()
		self.frame = view.bounds
		view.layer.addSublayer(self)
	}
	
	// required init stuff
	override init(session: AVCaptureSession!) {
		super.init(session: session)
	}
	
	required init(coder aDecoder: NSCoder) {
	    fatalError("init(coder:) has not been implemented")
	}
	
	// updates videoGravity to enable crop fit
	func aspectFill() {
		videoGravity = AVLayerVideoGravityResizeAspectFill
	}
}