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
	case Low
	case Medium
	case High
}

enum TurboCaptureResolution {
	case VGA
	case HD // not implemented
}

enum TurboCaptureCamera {
	case Front
	case Back
}

// MARK: - Video Capture Delegate Protocol
protocol TurboCaptureDelegate {
	func turboCaptureError(message: String)
	func turboCaptureMicrophoneDenied()
	func turboCaptureCameraDenied()
	func turboCaptureFinished(url: NSURL, thumbnail: UIImage?, duration: Double)
	func turboCaptureElapsed(seconds: Double)
}

// MARK: - Video Capture Class
class TurboCapture: TurboBase, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate, TurboCaptureWriterDelegate {
	// MARK: Private Properties
	private var delegate: TurboCaptureDelegate?
	private var previewLayer: TurboCapturePreviewLayer
	
	private var session: AVCaptureSession?
	private var outputUrl: NSURL?
	private var captureQueue: dispatch_queue_t?
	private var serialQueue: dispatch_queue_t?
	
	private var currentCamera: TurboCaptureCamera = TurboCaptureCamera.Front
	private var videoDevice: AVCaptureDevice?
	private var videoInput: AVCaptureDeviceInput?
	private var videoOutput: AVCaptureVideoDataOutput?

	private var audioInput: AVCaptureDeviceInput?
	private var audioDevice: AVCaptureDevice?
	private var audioOutput: AVCaptureAudioDataOutput?

	private var errorOccurred = false
	private var recording = false
	
	private var writer: TurboCaptureWriter?
	private var quality: TurboCaptureQuality
	private var resolution: TurboCaptureResolution
	
	// MARK: - Computed / Public Properties
	// number of seconds	
	var ready: Bool {
		return !errorOccurred && session != nil && videoDevice != nil && audioDevice != nil && videoInput != nil && audioInput != nil && videoOutput != nil && audioOutput != nil && outputUrl != nil && writer != nil
	}
	
	// the camera. defaults to front
	var camera: TurboCaptureCamera {
		set(camera) {
			// set current camera
			currentCamera = camera
			
			// update preview
			if ready {
				session?.beginConfiguration()
				
				var newVideoDevice = cameraDevice(currentCamera)!
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
				
				// portrait orientation - this is done in two places
				var connection = videoOutput?.connectionWithMediaType(AVMediaTypeVideo)
				if connection != nil && connection!.supportsVideoOrientation {
					connection!.videoOrientation = AVCaptureVideoOrientation.Portrait
				}
			}
		}
		get {
			return currentCamera
		}
	}
	
	// MARK: - Init Function
	init(previewLayer: TurboCapturePreviewLayer, resolution: TurboCaptureResolution, quality: TurboCaptureQuality, delegate: TurboCaptureDelegate?) {
		self.delegate = delegate
		self.previewLayer = previewLayer
		self.quality = quality
		self.resolution = resolution
		super.init()
		start()
	}
	
	// MARK: - Video / Audio Capture Data Output Delegate
	func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
		if ready && recording {
			dispatch_sync(serialQueue, {
				if captureOutput.connectionWithMediaType(AVMediaTypeAudio) == connection {
					self.writer?.write(TurboCaptureWriterMediaType.Audio, sampleBuffer: sampleBuffer)
				} else if captureOutput.connectionWithMediaType(AVMediaTypeVideo) == connection {
					self.writer?.write(TurboCaptureWriterMediaType.Video, sampleBuffer: sampleBuffer)
				}
			})
		}
	}
	
	// MARK: - Turbo Capture Writer Delegate
	func turboCaptureWriterError(message: String) {
		// pass error message up
		self.error(message)
	}
	
	func turboCaptureWriterElapsed(seconds: Double) {
		// have to make sure calling delegate from main queue
		main({
			self.delegate?.turboCaptureElapsed(seconds)
			return
		})
	}
	
	// writing output file finished!
	func turboCaptureWriterFinished() {
		// setup AVAsset to get a thumbnail and recording length
		var asset = AVURLAsset(URL: self.outputUrl!, options: nil)
		var generator = AVAssetImageGenerator(asset: asset)
		var error = NSErrorPointer()
		var time = CMTimeMake(1,60)
		var image = generator.copyCGImageAtTime(time, actualTime: nil, error: error)
		
		// Call finished delegate
		main({
			self.delegate?.turboCaptureFinished(self.outputUrl!, thumbnail: UIImage(CGImage: image), duration: CMTimeGetSeconds(asset.duration))
			return
		})
	}

	// MARK: - Recording Lifecycle
	// starts the preview
	private func start() {
		// check if already setup
		if ready {
			return
		}
		
		// Check for Camera Permissions
		var videoStatus = AVCaptureDevice.authorizationStatusForMediaType(AVMediaTypeVideo)
		
		if videoStatus == AVAuthorizationStatus.Denied {
			main({
				self.delegate?.turboCaptureCameraDenied()
				return
			})
			return
		}
		
		// Check for Microphone Permissions
		var audioStatus = AVCaptureDevice.authorizationStatusForMediaType(AVMediaTypeAudio)
		
		if audioStatus == AVAuthorizationStatus.Denied {
			main({
				self.delegate?.turboCaptureMicrophoneDenied()
				return
			})
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
		
		// setup video resolution
		switch resolution {
		default:
			if session != nil && session!.canSetSessionPreset(AVCaptureSessionPreset640x480) {
				session?.sessionPreset = AVCaptureSessionPreset640x480
			}
		}
		
		// setup preview layer
		previewLayer.session = session
		
		// setup capture queue
		captureQueue = dispatch_queue_create("com.shahan.turbocapture.capturequeue", DISPATCH_QUEUE_SERIAL)
		
		// setup video output
		videoOutput = AVCaptureVideoDataOutput()
		videoOutput?.setSampleBufferDelegate(self, queue: captureQueue)
		session?.addOutput(videoOutput)
		
		// portrait orientation - this is done in two places
		var connection = videoOutput?.connectionWithMediaType(AVMediaTypeVideo)
		if connection != nil && connection!.supportsVideoOrientation {
			connection!.videoOrientation = AVCaptureVideoOrientation.Portrait
		}
		
		// setup audio output
		audioOutput = AVCaptureAudioDataOutput()
		audioOutput?.setSampleBufferDelegate(self, queue: captureQueue)
		session?.addOutput(audioOutput)
		
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
		
		// setup assetwrite
		serialQueue = dispatch_queue_create("com.shahan.turbocapture.serialqueue", nil)
		writer = TurboCaptureWriter(url: outputUrl!, quality: quality, delegate: self)
		
		// start running the session
		session?.startRunning()
	}
	
	// stops recording and video capture
	func stop() {
		// make sure everything is ready (prevent nil errors)
		if !ready {
			return
		}
		
		// pause recording if needed
		if recording {
			pause()
		}
		
		// Create final output file
		writer?.stop()
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
		writer?.pause()
	}
	
	// MARK: - Multiple Cameras
	func cameraDevice(type: TurboCaptureCamera) -> AVCaptureDevice? {
		var devices = AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo)
		
		for device in devices as [AVCaptureDevice] {
			if type == TurboCaptureCamera.Back && device.position == AVCaptureDevicePosition.Back {
				return device
			}
			
			if type == TurboCaptureCamera.Front && device.position == AVCaptureDevicePosition.Front {
				return device
			}
		}
		
		if devices.count == 0 {
			return nil
		}
		
		return devices[0] as? AVCaptureDevice
	}
	
	func availableCameras() -> [TurboCaptureCamera] {
		var cameras: [TurboCaptureCamera] = []
		
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
	
	func switchCamera() {
		// cant switch camera if not ready or already recording
		if !ready || recording {
			return
		}
		
		var cameras = availableCameras()
		
		if cameras.count > 1 {
			if camera == cameras[0] {
				camera = cameras[1]
			} else {
				camera = cameras[0]
			}
		}
	}
	
	// MARK: - Error Handling
	private func throw(message :String) {
		errorOccurred = true
		NSException(name: "VideoCaptureException", reason: message, userInfo: nil).raise()
	}
	
	private func error(message :String) {
		errorOccurred = true
		main({
			self.delegate?.turboCaptureError(message)
			return
		})
	}
}