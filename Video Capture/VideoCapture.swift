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

protocol VideoCaptureDelegate {
	func videoCaptureReady()
	func videoCaptureError(message :String)
}

class VideoCapture {
	// MARK Private Properties
	private var delegate :VideoCaptureDelegate?
	private var previewLayer :VideoCapturePreviewLayer?
	private var session :AVCaptureSession?
	private var videoDevice :AVCaptureDevice?
	private var audioDevice :AVCaptureDevice?
	private var videoInput :AVCaptureDeviceInput?
	private var audioInput :AVCaptureDeviceInput?
	private var errorOccurred = false
	private var recording = false
	
	// MARK - Computed / Public Properties
	var ready: Bool {
		return !errorOccurred && session != nil && videoDevice != nil && audioDevice != nil && videoInput != nil && audioInput != nil
	}
	
	// MARK - Init Function
	init(previewLayer :VideoCapturePreviewLayer?, delegate :VideoCaptureDelegate?) {
		self.delegate = delegate
		self.previewLayer = previewLayer
		start()
	}

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
		
		
		// setup preview layer
		previewLayer?.session = session
		
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
	}
	
	// start video recording
	func record() {
		if !ready {
			throw("Need to check if ready before trying to record")
			return
		}
		
		recording = true
	}
	
	// pause video recording
	func pause() {
		if !recording {
			throw("Need to be recording before you can pause")
			return
		}
	}
	
	private func throw(message :String) {
		errorOccurred = true
		NSException(name: "VideoCaptureException", reason: message, userInfo: nil).raise()
	}
	
	private func error(message :String) {
		errorOccurred = true
		delegate?.videoCaptureError(message)
	}
}