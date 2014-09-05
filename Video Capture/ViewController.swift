//
//  ViewController.swift
//  Video Capture
//
//  Created by Shahan Khan on 9/4/14.
//  Copyright (c) 2014 Shahan Khan. All rights reserved.
//

import UIKit

class ViewController: UIViewController, VideoCaptureDelegate {
	// MARK Instance Variables
	var videoCapture :VideoCapture? = nil
	var previewLayer :VideoCapturePreviewLayer? = nil
	
	// MARK IBOutlets
	@IBOutlet weak var previewView: UIView!
	
	// MARK - Handle Record Button
	@IBAction func startRecording(sender: AnyObject) {
		videoCapture?.record()
	}
	
	@IBAction func stopRecording(sender: AnyObject) {
		videoCapture?.pause()
	}
	
	// MARK - Video Capture Delegate
	func videoCaptureReady() {
	}
	
	func videoCaptureError(message :String) {
		UIAlertView(title: "Error", message: message, delegate: nil, cancelButtonTitle: "Ok").show()
		NSLog(message)
	}
	
	// MARK - View Controller Lifecycle
	override func viewDidLoad() {
		super.viewDidLoad()
		
		// setup the preview layer
		previewLayer = VideoCapturePreviewLayer(view: previewView)
		previewLayer?.cropFit()
		
		// setup video capture + preview
		videoCapture = VideoCapture(previewLayer: previewLayer, delegate: self)
	}
	
	override func prefersStatusBarHidden() -> Bool {
		return true
	}
}

