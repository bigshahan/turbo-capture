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
	func turboCaptureWriterElapsed(seconds	:Float)
	func turboCaptureWriterFinished()
}

// basically wraps AVAssetWriter with inputs
class TurboCaptureWriter: TurboBase {
	var delegate :TurboCaptureWriterDelegate?
	
	private var writer: AVAssetWriter?
	private var audioInput: AVAssetWriterInput?
	private var videoInput: AVAssetWriterInput?
	private var errorOccurred = false
	
	// used for time correction on pauses
	private var lastVideoTime :CMTime?
	private var lastAudioTime :CMTime?
	
	// time first sample came at
	private var startTime: CMTime?
	
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
			AVFormatIDKey:kAudioFormatMPEG4AAC,
			AVSampleRateKey: 44100.0,
			AVNumberOfChannelsKey: 1,
			AVEncoderBitRateKey: 64000
		]
		audioInput = AVAssetWriterInput(mediaType: AVMediaTypeAudio, outputSettings: nil)
		audioInput?.expectsMediaDataInRealTime = true
		
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
		
		// get timing information from buffer
		var delta = CMTimeMakeWithSeconds(0, 10000)
		var start = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
		var duration = CMSampleBufferGetDuration(sampleBuffer)
		
		// update start and duration with offset adjustments
		start = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
		duration = CMSampleBufferGetDuration(sampleBuffer)
		
		// calculate time adjustments on sample buffer times to account for pauses
		if type == TurboCaptureWriterMediaType.Video && videoInput!.readyForMoreMediaData && lastVideoTime != nil {
			NSLog("Video")
			delta = CMTimeSubtract(start, lastVideoTime!)
		} else if type == TurboCaptureWriterMediaType.Audio && audioInput!.readyForMoreMediaData && lastAudioTime != nil {
			NSLog("Audio")
			delta = CMTimeSubtract(start, lastAudioTime!)
		}
		
		NSLog("Delta in seconds: \(CMTimeGetSeconds(delta))")
		
		// adjust sample buffer times to account for pauses
		if CMTimeGetSeconds(delta) > 0 {
			// do adjustment
//			NSLog("Need to adjust buffer by \(CMTimeGetSeconds(delta)) seconds")
			
			// update the start time of sample buffer
			start = CMTimeSubtract(start, delta)
		}

		// handle video write
		if type == TurboCaptureWriterMediaType.Video && videoInput!.readyForMoreMediaData {
			videoInput?.appendSampleBuffer(sampleBuffer)
			lastVideoTime = start
			
		// handle audio writes
		} else if type == TurboCaptureWriterMediaType.Audio && audioInput!.readyForMoreMediaData {
			audioInput?.appendSampleBuffer(sampleBuffer)
			
			// set startTime if not yet set
			if startTime == nil {
				startTime = start
			}
			
			// determine duration and trigger delegate
			var elapsed = CMTimeSubtract(CMTimeAdd(start, duration), startTime!)
			delegate?.turboCaptureWriterElapsed(Float(CMTimeGetSeconds(elapsed)))
			
			// set last audio time
			lastAudioTime = CMTimeAdd(start, duration)
		}
	}
	
	func stop() {
		if !ready || writer!.status != AVAssetWriterStatus.Writing {
			return
		}
		
		// close file for writing
		writer?.finishWritingWithCompletionHandler({
			// clear out everything
			self.delegate?.turboCaptureWriterFinished()
			self.errorOccurred = false
			self.startTime = nil
		})
	}
	
	private func error(message :String) {
		errorOccurred = true
		delegate?.turboCaptureWriterError(message)
	}
}
