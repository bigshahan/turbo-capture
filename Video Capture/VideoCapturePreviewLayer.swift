//
//  VideoCaptureLayer.swift
//  Video Capture
//
//  Created by Shahan Khan on 9/5/14.
//  Copyright (c) 2014 Shahan Khan. All rights reserved.
//

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
	func cropFit() {
		videoGravity = AVLayerVideoGravityResizeAspectFill
	}
}