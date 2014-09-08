//
//  TurboCaptureWriter.swift
//  Turbo Capture
//
//  Created by Shahan Khan on 9/8/14.
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
import AVFoundation

enum TurboCaptureWriterMediaType {
	case Video
	case Audio
}

// delegate
protocol TurboCaptureWriterDelegate {
	func turboCaptureWriterError(message :String)
}

// basically wraps AVAssetWriter with inputs
class TurboCaptureWriter: NSObject {
	var delegate :TurboCaptureWriterDelegate?
	
	private var writer :AVAssetWriter?
	private var audioInput :AVAssetWriterInput?
	private var videoInput :AVAssetWriterInput?
	private var errorOccurred = false
	
	var ready :Bool {
		get {
			return !errorOccurred && writer != nil && audioInput != nil && videoInput != nil
		}
	}
	
	init(url: NSURL, delegate: TurboCaptureWriterDelegate?) {
		super.init()

		// setup delegate
		self.delegate = delegate
		
		// setup writer
		var err = NSErrorPointer()
		writer = AVAssetWriter(URL: url, fileType: AVFileTypeQuickTimeMovie, error: err)
		
		if err != nil {
			error("Could not initialize asset writer")
			return
		}
		
		// setup audio input
		var audioSettings = [
			AVFormatIDKey:kAudioFormatMPEG4AAC
		]
		audioInput = AVAssetWriterInput(mediaType: AVMediaTypeAudio, outputSettings: nil)
		
		// setup video input
		var videoSettings = [
			AVVideoCodecKey: AVVideoCodecH264,
			AVVideoWidthKey: 480,
			AVVideoHeightKey: 640
		]
		videoInput = AVAssetWriterInput(mediaType: AVMediaTypeVideo, outputSettings: videoSettings)
		videoInput?.expectsMediaDataInRealTime = true
		
		// add inputs to AVAssetWriter
		if writer!.canAddInput(audioInput) {
			writer?.addInput(audioInput)
		} else {
			error("Could not add audio input to asset writer")
			return
		}
		
		if writer!.canAddInput(videoInput) {
			writer?.addInput(videoInput)
		} else {
			error("Could not add video input to asset writer")
			return
		}
	}
	
	func write(type: TurboCaptureWriterMediaType, sampleBuffer: CMSampleBuffer) {
		// can't write if not ready
		if !ready {
			return
		}
		
		// make sure writer is setup
		if writer?.status == AVAssetWriterStatus.Unknown {
			writer?.startWriting()
			writer?.startSessionAtSourceTime(CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
		}
		
		if writer?.status == AVAssetWriterStatus.Failed {
			error("AVAssetWriter error \(writer?.error.localizedDescription)")
			return
		}
		
		// handle video
		if type == TurboCaptureWriterMediaType.Video && videoInput!.readyForMoreMediaData {
			videoInput?.appendSampleBuffer(sampleBuffer)
			NSLog("Video sample buffer!")
		
		// handle audio
		} else if type == TurboCaptureWriterMediaType.Audio && audioInput!.readyForMoreMediaData {
			audioInput?.appendSampleBuffer(sampleBuffer)
			NSLog("Audio sample buffer!")
		}
	}
	
	func stop() {
		if !ready {
			return
		}
		
		// close file for writing
		writer?.finishWritingWithCompletionHandler({
			// clear out everything
			self.clear()
		})
	}
	
	private func clear() {
		writer = nil
		audioInput = nil
		videoInput = nil
		errorOccurred = false
	}
	
	private func error(message :String) {
		errorOccurred = true
		delegate?.turboCaptureWriterError(message)
	}
}
