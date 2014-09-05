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
	private var delegate :VideoCaptureDelegate?
	private var previewLayer :AVCaptureVideoPreviewLayer?

	private var ready = false
	private var session :AVCaptureSession?
	private var videoDevice :AVCaptureDevice?
	private var audioDevice :AVCaptureDevice?
	private var videoInput :AVCaptureDeviceInput?
	private var audioInput :AVCaptureDeviceInput?
	
	init(previewLayer :AVCaptureVideoPreviewLayer?, delegate :VideoCaptureDelegate?) {
		self.delegate = delegate
		self.previewLayer = previewLayer

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
		ready = true
		delegate?.videoCaptureReady()
	}
	
	func stop() {
		session?.stopRunning()
		ready = false
		session = nil
		videoDevice = nil
		videoInput = nil
		audioDevice = nil
		audioInput = nil
	}
	
	private func error(message :String) {
		delegate?.videoCaptureError(message)
	}
}