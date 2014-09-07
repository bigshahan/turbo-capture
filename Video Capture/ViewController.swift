//
//  ViewController.swift
//  Video Capture
//
//  Created by Shahan Khan on 9/4/14.
//  Copyright (c) 2014 Shahan Khan. All rights reserved.
//

import UIKit
import MediaPlayer

class ViewController: UIViewController, VideoCaptureDelegate {
	// MARK: Properties
	var videoCapture :VideoCapture? = nil
	var previewLayer :VideoCapturePreviewLayer? = nil
	
	// MARK: IBOutlets
	@IBOutlet weak var previewView: UIView!
	
	// MARK: - Switch Camera
	@IBAction func switchCamera(sender: AnyObject) {
		if videoCapture != nil {
			var cameras = videoCapture!.availableCameras()
			
			if cameras.count > 1 {
				if videoCapture!.camera == cameras[0] {
					videoCapture?.camera = cameras[1]
				} else {
					videoCapture?.camera = cameras[0]
				}
			}
		}
	}
	
	// MARK: - Handle Record Button
	@IBAction func startRecording(sender: AnyObject) {
		if videoCapture != nil && videoCapture!.ready {
			videoCapture?.record()
		}
	}
	
	@IBAction func stopRecording(sender: AnyObject) {
		videoCapture?.pause()
	}
	
	// MARK: - Video Capture Delegate
	func videoCaptureError(message :String) {
		UIAlertView(title: "Error", message: "Could not activate the camera or microphone.", delegate: nil, cancelButtonTitle: "Ok").show()
		NSLog(message)
	}
	
	func videoCaptureCameraDenied() {
		UIAlertView(title: "This app does not have access to your camera.", message: "You can enable access in Privacy Settings.", delegate: nil, cancelButtonTitle: "Ok").show()
	}
	
	func videoCaptureMicrophoneDenied() {
		UIAlertView(title: "This app does not have access to your microphone.", message: "You can enable access in Privacy Settings.", delegate: nil, cancelButtonTitle: "Ok").show()
	}
	
	func videoCaptureFinished(url :NSURL) {
		NSLog("\(url)")
		var controller = MPMoviePlayerViewController(contentURL: url)
		presentMoviePlayerViewControllerAnimated(controller)
	}
	
	// MARK: - View Controller Lifecycle
	override func viewDidLoad() {
		super.viewDidLoad()
		
		// setup the preview layer
		previewLayer = VideoCapturePreviewLayer(view: previewView)
		previewLayer?.cropFit()
	
		// setup video capture + preview
		videoCapture = VideoCapture(previewLayer: previewLayer, delegate: self)
		videoCapture?.start()
	}
	
	override func prefersStatusBarHidden() -> Bool {
		return true
	}
}

