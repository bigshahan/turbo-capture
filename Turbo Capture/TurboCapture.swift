//
//  TurboCapture.swift
//  Turbo Capture
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

import Foundation
import CoreMedia
import AVFoundation
import AssetsLibrary
import UIKit

enum TurboCaptureQuality {
	case Normal
}

enum TurboCaptureCamera {
	case Front
	case Back
}

// MARK: - Video Capture Delegate Protocol
protocol TurboCaptureDelegate {
	func turboCaptureError(message :String)
	func turboCaptureMicrophoneDenied()
	func turboCaptureCameraDenied()
	func turboCaptureFinished(url :NSURL)
	func turboCaptureElapsed(seconds: Double)
}

// MARK: - Video Capture Class
class TurboCapture: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate, TurboCaptureWriterDelegate {
	// MARK: Private Properties
	private var delegate :TurboCaptureDelegate?
	private var previewLayer :TurboCapturePreviewLayer?
	
	private var session :AVCaptureSession?
	private var outputUrl :NSURL?
	private var captureQueue :dispatch_queue_t?
	private var serialQueue :dispatch_queue_t?
	
	private var currentCamera :TurboCaptureCamera = TurboCaptureCamera.Front
	private var videoDevice :AVCaptureDevice?
	private var videoInput :AVCaptureDeviceInput?
	private var videoOutput :AVCaptureVideoDataOutput?

	private var audioInput :AVCaptureDeviceInput?
	private var audioDevice :AVCaptureDevice?
	private var audioOutput :AVCaptureAudioDataOutput?

	private var errorOccurred = false
	private var recording = false
	private var elapsed = 0.0
	
	private var writer :TurboCaptureWriter?
	
	// MARK: - Computed / Public Properties
	// number of seconds
	var duration = 10.0
	
	var ready: Bool {
		return !errorOccurred && session != nil && videoDevice != nil && audioDevice != nil && videoInput != nil && audioInput != nil && videoOutput != nil && audioOutput != nil && outputUrl != nil && writer != nil
	}
	
	// quality is only set when start is called
	var quality :TurboCaptureQuality = TurboCaptureQuality.Normal
	
	// the camera. defaults to front
	var camera :TurboCaptureCamera {
		set(camera) {
			// set current camera
			currentCamera = camera
			
			// update preview
			if ready {
				session?.beginConfiguration()
				
				var newVideoDevice = cameraDevice(currentCamera)
				var error = NSErrorPointer()
				var newVideoInput = AVCaptureDeviceInput(device: newVideoDevice, error: error)
				
				if error == nil {
					session?.removeInput(videoInput)
					videoInput = newVideoInput
					videoDevice = newVideoDevice
					
					if session!.canAddInput(videoInput) {
						session?.addInput(videoInput)
					}
				}
				
				session?.commitConfiguration()
			}
		}
		get {
			return currentCamera
		}
	}
	
	// MARK: - Init Function
	// duration is number of seconds
	init(previewLayer :TurboCapturePreviewLayer?, delegate :TurboCaptureDelegate?) {
		self.delegate = delegate
		self.previewLayer = previewLayer
	}
	
	// MARK: - Video / Audio Capture Data Output Delegate
	func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
		if ready && recording {
			dispatch_sync(serialQueue, {
				if captureOutput.connectionWithMediaType(AVMediaTypeAudio) == connection {
					self.writer?.write(TurboCaptureWriterMediaType.Audio, sampleBuffer: sampleBuffer)
				} else {
					self.writer?.write(TurboCaptureWriterMediaType.Video, sampleBuffer: sampleBuffer)
				}
			})
		}
	}
	
	// MARK: - Turbo Capture Writer Delegate
	func turboCaptureWriterError(message: String) {
		error(message)
	}

	// MARK: - Recording Lifecycle
	// starts the preview
	func start() {
		// check if already setup
		if ready {
			return
		}
		
		// Check for Camera Permissions
		var videoStatus = AVCaptureDevice.authorizationStatusForMediaType(AVMediaTypeVideo)
		
		if videoStatus == AVAuthorizationStatus.Denied {
			delegate?.turboCaptureCameraDenied()
			return
		}
		
		// Check for Microphone Permissions
		var audioStatus = AVCaptureDevice.authorizationStatusForMediaType(AVMediaTypeAudio)
		
		if audioStatus == AVAuthorizationStatus.Denied {
			delegate?.turboCaptureMicrophoneDenied()
			return
		}
		
		// setup video capturing session
		session = AVCaptureSession()
		
		// setup video device
		videoDevice = cameraDevice(currentCamera)
		
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
				error("Could not add video device input to session")
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
				error("Could not add audio device input to session")
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
		
		// setup capture queue
		captureQueue = dispatch_queue_create("com.shahan.turbocapture.capturequeue", DISPATCH_QUEUE_SERIAL)
		
		// setup video output
		videoOutput = AVCaptureVideoDataOutput()
		videoOutput?.setSampleBufferDelegate(self, queue: captureQueue)
		session?.addOutput(videoOutput)
		
		// setup audio output
		audioOutput = AVCaptureAudioDataOutput()
		audioOutput?.setSampleBufferDelegate(self, queue: captureQueue)
		session?.addOutput(audioOutput)
		
		// get a temporary file for output
		var path = "\(NSTemporaryDirectory())output.mov"
		outputUrl = NSURL(fileURLWithPath: path)
		
		// setup assetwrite
		serialQueue = dispatch_queue_create("com.shahan.turbocapture.serialqueue", nil)
		writer = TurboCaptureWriter(url: outputUrl!, delegate: self)
		
		// start running the session
		session?.startRunning()
	}
	
	// stops recording and video capture
	func stop() {
		// pause recording if needed
		if recording {
			pause()
		}
		
		// TODO: create final output file
		
		
		// TODO: call finished delegate
		
		
		// end session
		session?.stopRunning()
		errorOccurred = false
		session = nil
		videoDevice = nil
		videoInput = nil
		videoOutput = nil
		audioDevice = nil
		audioInput = nil
		audioOutput = nil
		captureQueue = nil
		serialQueue = nil
		outputUrl = nil
		writer = nil
		elapsed = 0
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
		recording = false
	}
	
	// MARK: - Multiple Cameras
	func cameraDevice(type: TurboCaptureCamera) -> AVCaptureDevice {
		var devices = AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo)
		
		for device in devices as [AVCaptureDevice] {
			if type == TurboCaptureCamera.Back && device.position == AVCaptureDevicePosition.Back {
				return device
			}
			
			if type == TurboCaptureCamera.Front && device.position == AVCaptureDevicePosition.Front {
				return device
			}
		}
		
		return devices[0] as AVCaptureDevice
	}
	
	func availableCameras() -> [TurboCaptureCamera] {
		var cameras :[TurboCaptureCamera] = []
		
		// get cameras
		var devices = AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo)
		
		for device in devices as [AVCaptureDevice] {
			if device.position == AVCaptureDevicePosition.Back {
				cameras.append(TurboCaptureCamera.Back)
			} else {
				cameras.append(TurboCaptureCamera.Front)
			}
		}
		
		return cameras
	}
	
	// MARK: - Error Handling
	private func throw(message :String) {
		errorOccurred = true
		NSException(name: "VideoCaptureException", reason: message, userInfo: nil).raise()
	}
	
	private func error(message :String) {
		errorOccurred = true
		delegate?.turboCaptureError(message)
	}
}