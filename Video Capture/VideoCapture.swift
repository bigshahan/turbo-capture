//
//  VideoCapture.swift
//  Video Capture
//
//  Created by Shahan Khan on 9/4/14.
//  Copyright (c) 2014 Shahan Khan. All rights reserved.
//

import Foundation
import CoreMedia
import AVFoundation
import AssetsLibrary
import UIKit

enum VideoCaptureQuality {
	case Normal
}

enum VideoCaptureCamera {
	case Front
	case Back
}

protocol VideoCaptureDelegate {
	func videoCaptureReady()
	func videoCaptureError(message :String)
	func videoCaptureFinished(url :NSURL)
}

class VideoCapture: NSObject, AVCaptureFileOutputRecordingDelegate {
	// MARK Private Properties
	private var delegate :VideoCaptureDelegate?
	private var previewLayer :VideoCapturePreviewLayer?
	
	private var session :AVCaptureSession?
	private var output :AVCaptureMovieFileOutput?
	private var outputUrl :NSURL?
	
	private var currentCamera :VideoCaptureCamera = VideoCaptureCamera.Front
	private var videoDevice :AVCaptureDevice?
	private var videoInput :AVCaptureDeviceInput?
	
	private var audioInput :AVCaptureDeviceInput?
	private var audioDevice :AVCaptureDevice?

	private var errorOccurred = false
	private var recording = false
	
	// number of seconds
	private var duration = 10.0
	
	// MARK - Computed / Public Properties
	var ready: Bool {
		return !errorOccurred && session != nil && videoDevice != nil && audioDevice != nil && videoInput != nil && audioInput != nil && output != nil && outputUrl != nil
	}
	
	// quality is only set when start is called
	var quality :VideoCaptureQuality = VideoCaptureQuality.Normal
	
	// the camera. defaults to front
	var camera :VideoCaptureCamera {
		set(camera) {
			currentCamera = camera
			
			// update camera
			if ready {
				
			}
		}
		get {
			return currentCamera
		}
	}
	
	// MARK - Init Function
	// duration is number of seconds
	init(previewLayer :VideoCapturePreviewLayer?, delegate :VideoCaptureDelegate?, duration: Double) {
		self.delegate = delegate
		self.previewLayer = previewLayer
		self.duration = duration
	}

	// MARK - Recording Lifecycle
	// starts the preview
	func start() {
		// check if already setup
		if ready {
			return
		}
		
		// setup video capturing session
		session = AVCaptureSession()
		
		// setup video device
		videoDevice = AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeVideo)
		
		if videoDevice == nil {
			error("Could not setup a video capture device")
			return
		}
		
		// setup video input
		var err = NSErrorPointer()
		videoInput = AVCaptureDeviceInput.deviceInputWithDevice(videoDevice, error: err) as? AVCaptureDeviceInput
		
		if err == nil {
			if (session?.canAddInput(videoInput) != nil) {
				session?.addInput(videoInput)
			} else {
				error("Can not add video device input to session")
				return
			}
		} else {
			error("Could not create a video device input")
			return
		}
		
		// setup audio input
		audioDevice	= AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeAudio)
		
		if audioDevice == nil {
			error("Could not setup an audio capture device")
			return
		}
		
		// setup audio device
		err = NSErrorPointer()
		audioInput = AVCaptureDeviceInput.deviceInputWithDevice(audioDevice, error: err) as? AVCaptureDeviceInput
		
		if err == nil {
			if (session?.canAddInput(audioInput) != nil) {
				session?.addInput(audioInput)
			} else {
				error("Can not add audio device input to session")
				return
			}
		} else {
			error("Could not create an audio device input")
			return
		}
		
		// setup video qualtity
		switch quality {
		default:
			if session? != nil && session!.canSetSessionPreset(AVCaptureSessionPreset640x480) {
				session?.sessionPreset = AVCaptureSessionPreset640x480
			}
		}
		
		// setup preview layer
		previewLayer?.session = session
		
		// setup output
		output = AVCaptureMovieFileOutput()
		output?.maxRecordedDuration = CMTimeMakeWithSeconds(duration, 30)
		output?.minFreeDiskSpaceLimit = 1024 * 1024 * 50
		
		if session? != nil && session!.canAddOutput(output) {
			session?.addOutput(output)
		} else {
			error("Could not add file output")
			return
		}
		
		// get a temporary file for output
		var path = "\(NSTemporaryDirectory())output.mov"
		
		var fileManager = NSFileManager.defaultManager()
		if fileManager.fileExistsAtPath(path) {
			var error = NSErrorPointer()
			
			if !fileManager.removeItemAtPath(path, error: error) {
				self.error("A duplicate output file could not be removed from the output directory")
				return
			}
		}
		
		outputUrl = NSURL(fileURLWithPath: path)
		
		// start running
		session?.startRunning()
		
		// everything is setup so its ready to go
		delegate?.videoCaptureReady()
	}
	
	// stops recording and video capture
	func stop() {
		if recording {
			pause()
		}
		
		session?.stopRunning()
		errorOccurred = false
		session = nil
		videoDevice = nil
		videoInput = nil
		audioDevice = nil
		audioInput = nil
		output = nil
		outputUrl = nil
	}
	
	// start video recording
	func record() {
		if !ready {
			throw("Need to check if ready before trying to record")
			return
		}
		
		if !recording {
			output?.startRecordingToOutputFileURL(outputUrl, recordingDelegate: self)
			recording = true
		}
	}
	
	// pause video recording
	func pause() {
		if !recording {
			return
		}
		recording = false
		output?.stopRecording()
	}
	
	// MARK - Multiple Cameras
	func availableCameras() -> [VideoCaptureCamera] {
		var cameras :[VideoCaptureCamera] = []
		
		// check if a front camera is available
		
		
		// check if a back camera is available
		
		
		return cameras
	}
	
	// MARK - Capture Output Delegate
	func captureOutput(captureOutput: AVCaptureFileOutput!, didStartRecordingToOutputFileAtURL fileURL: NSURL!, fromConnections connections: [AnyObject]!) {
		NSLog("started recording \(CMTimeGetSeconds(captureOutput.recordedDuration))")
	}
	
	func captureOutput(captureOutput: AVCaptureFileOutput!, didFinishRecordingToOutputFileAtURL outputFileURL: NSURL!, fromConnections connections: [AnyObject]!, error: NSError!) {
		NSLog("stopped recording \(CMTimeGetSeconds(captureOutput.recordedDuration))")
		if CMTimeGetSeconds(captureOutput.recordedDuration) >= duration {
			stop()
			self.delegate?.videoCaptureFinished(outputFileURL)
		}
	}
	
	// MARK - Error Handling
	private func throw(message :String) {
		errorOccurred = true
		NSException(name: "VideoCaptureException", reason: message, userInfo: nil).raise()
	}
	
	private func error(message :String) {
		errorOccurred = true
		delegate?.videoCaptureError(message)
	}
}