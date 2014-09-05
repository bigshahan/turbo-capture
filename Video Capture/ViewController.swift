//
//  ViewController.swift
//  Video Capture
//
//  Created by Shahan Khan on 9/4/14.
//  Copyright (c) 2014 Shahan Khan. All rights reserved.
//

import UIKit

class ViewController: UIViewController, VideoCaptureDelegate {
	var videoCapture :VideoCapture? = nil
	var previewLayer :VideoCaptureLayer? = nil
	
	@IBOutlet weak var previewView: UIView!
	
	@IBAction func startRecording(sender: AnyObject) {
	}
	
	@IBAction func stopRecording(sender: AnyObject) {
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		// setup the preview layer
		previewLayer = VideoCaptureLayer()
		previewLayer?.cropFit()
		previewLayer?.frame = previewView.bounds
		previewView.layer.addSublayer(previewLayer)
		
		// setup video capture
		videoCapture = VideoCapture(previewLayer: previewLayer, delegate: self)
	}
	
	// MARK - Video Capture Delegate
	func videoCaptureReady() {
	}
	
	func videoCaptureError(message :String) {
		UIAlertView(title: "Error", message: message, delegate: nil, cancelButtonTitle: "Ok").show()
		NSLog(message)
	}
	
	// because hiding the status bar is cool
	override func prefersStatusBarHidden() -> Bool {
		return true
	}
}

