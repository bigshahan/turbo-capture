//
//  ViewController.swift
//  Video Capture
//
//  Created by Shahan Khan on 9/4/14.
//  Copyright (c) 2014 Shahan Khan.
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

import UIKit
import MediaPlayer

class ViewController: UIViewController, TurboCaptureDelegate {
	// MARK: Properties
	var videoCapture :TurboCapture? = nil
	var previewLayer :TurboCapturePreviewLayer? = nil
	
	// MARK: IBOutlets
	@IBOutlet weak var previewView: UIView!
	@IBOutlet weak var progressView: UIProgressView!
	
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
	func turboCaptureError(message :String) {
		UIAlertView(title: "Error", message: "Could not activate the camera or microphone.", delegate: nil, cancelButtonTitle: "Ok").show()
		NSLog(message)
	}
	
	func turboCaptureCameraDenied() {
		UIAlertView(title: "This app does not have access to your camera.", message: "You can enable access in Privacy Settings.", delegate: nil, cancelButtonTitle: "Ok").show()
	}
	
	func turboCaptureMicrophoneDenied() {
		UIAlertView(title: "This app does not have access to your microphone.", message: "You can enable access in Privacy Settings.", delegate: nil, cancelButtonTitle: "Ok").show()
	}
	
	func turboCaptureFinished(url :NSURL) {
		NSLog("\(url)")
		var controller = MPMoviePlayerViewController(contentURL: url)
		presentMoviePlayerViewControllerAnimated(controller)
		reset()
	}
	
	func turboCaptureElapsed(seconds: Double) {
		progressView.setProgress(Float(seconds/10.0), animated: true)
	}

	// MARK: - View Controller Lifecycle
	func reset() {
		videoCapture?.start()
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		// setup the preview layer
		previewLayer = TurboCapturePreviewLayer(view: previewView)
		previewLayer?.aspectFill()
	
		// setup video capture + preview
		videoCapture = TurboCapture(previewLayer: previewLayer, delegate: self)
		videoCapture?.start()
	}
	
	override func prefersStatusBarHidden() -> Bool {
		return true
	}
}
