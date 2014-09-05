//
//  ViewController.swift
//  Video Capture
//
//  Created by Shahan Khan on 9/4/14.
//  Copyright (c) 2014 Shahan Khan. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController, VideoCaptureDelegate {
	var videoCapture :VideoCapture? = nil
	var previewLayer :AVCaptureVideoPreviewLayer? = nil
	
	@IBOutlet weak var previewView: UIView!
	
	@IBAction func startRecording(sender: AnyObject) {
	}
	
	@IBAction func stopRecording(sender: AnyObject) {
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		// setup the preview layer
		previewLayer = AVCaptureVideoPreviewLayer()
		previewLayer?.bounds = previewView.layer.bounds
		previewView.layer.addSublayer(previewLayer)
		
		// setup video capture
		videoCapture = VideoCapture(fromPreviewLayer: previewLayer, delegate: self)
	}
	
	// MARK - Video Capture Delegate
	func videoCaptureReady() {
		
	}
	
	func videoCaptureError(message :String) {
		UIAlertView(title: "Error", message: message, delegate: nil, cancelButtonTitle: "Ok").show()
		NSLog(message)
	}
}

