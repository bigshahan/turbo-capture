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
	func turboCaptureWriterError(message: String)
	func turboCaptureWriterElapsed(seconds: Double)
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
	private var videoDelta = CMTimeMakeWithSeconds(0, 1000000000)
	private var audioDelta = CMTimeMakeWithSeconds(0, 1000000000)
	
	private var lastVideoTime: CMTime?
	private var lastAudioTime: CMTime?
	
	private var updateVideoTime = false
	private var updateAudioTime = false
	
	private var quality: TurboCaptureQuality
	private var type: TurboCaptureType
	
	// time first sample came at
	private var startTime: CMTime?
	
	var ready :Bool {
		get {
			return !errorOccurred && writer != nil && audioInput != nil && videoInput != nil
		}
	}
	
	init(url: NSURL, quality: TurboCaptureQuality, type:TurboCaptureType, delegate: TurboCaptureWriterDelegate?) {
		// set the quality
		self.quality = quality
		self.type = type
		
		// initialize
		super.init()
		
		// setup delegate
		self.delegate = delegate
		
		// setup writer
		var err: NSError?
		var type = AVFileTypeQuickTimeMovie
		
		if self.type == .MP4 {
			type = AVFileTypeMPEG4
		}
		
		writer = AVAssetWriter(URL: url, fileType: type, error: &err)
		
		if err != nil {
			error("Could not initialize asset writer")
			return
		}
		
		// setup audio input
		var audioSettings = [
			AVFormatIDKey: kAudioFormatMPEG4AAC,
			AVSampleRateKey: 44100.0,
			AVNumberOfChannelsKey: 1,
			AVEncoderBitRateKey: 64000
		]
		audioInput = AVAssetWriterInput(mediaType: AVMediaTypeAudio, outputSettings: audioSettings as [NSObject : AnyObject])
		audioInput?.expectsMediaDataInRealTime = true
		
		// add audio input to asset writer
		if writer!.canAddInput(audioInput) {
			writer?.addInput(audioInput)
		} else {
			error("Could not add audio input to asset writer")
			return
		}
		
		// setup video input
        var videoSettings: Dictionary<NSObject, AnyObject> = [
			AVVideoCodecKey: AVVideoCodecH264,
			AVVideoWidthKey: 480,
			AVVideoHeightKey: 640
		]
		
		// setup quality
		if quality == .Low {
			videoSettings[AVVideoCompressionPropertiesKey] = [AVVideoAverageBitRateKey: 350000]
		}
		
		if quality == .Medium {
			videoSettings[AVVideoCompressionPropertiesKey] = [AVVideoAverageBitRateKey: 700000]
		}
		
		if quality == .High {
			videoSettings[AVVideoCompressionPropertiesKey] = [AVVideoAverageBitRateKey: 1200000]
		}
		
        videoInput = AVAssetWriterInput(mediaType: AVMediaTypeVideo, outputSettings: videoSettings as [NSObject: AnyObject])
		videoInput?.expectsMediaDataInRealTime = true
		
		// add video input to AVAssetWriter
		if writer!.canAddInput(videoInput) {
			writer?.addInput(videoInput)
		} else {
			error("Could not add video input to asset writer")
			return
		}
	}
	
	func write(type: TurboCaptureWriterMediaType, sampleBuffer: CMSampleBuffer) {
		var buffer = sampleBuffer
		
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
			error("AVAssetWriter error \(writer!.error) \(writer?.error.code) \(writer?.error.localizedDescription)")
			return
		}
		
		if writer?.status != AVAssetWriterStatus.Writing {
			return
		}
		
		// get timing information from buffer
		var start = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
		var duration = CMSampleBufferGetDuration(sampleBuffer)
		var delta = CMTimeMakeWithSeconds(0, 1000000000)
		
		// update start and duration with offset adjustments
		start = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
		duration = CMSampleBufferGetDuration(sampleBuffer)
		
		// calculate time adjustments on sample buffer times to account for pauses
		if type == TurboCaptureWriterMediaType.Video && videoInput!.readyForMoreMediaData && lastVideoTime != nil {
			if updateVideoTime {
				videoDelta = CMTimeSubtract(start, lastVideoTime!)
				updateVideoTime = false
			}
			
			delta = videoDelta
			
		} else if type == TurboCaptureWriterMediaType.Audio && audioInput!.readyForMoreMediaData && lastAudioTime != nil {
			if updateAudioTime {
				audioDelta = CMTimeSubtract(start, lastAudioTime!)
				updateAudioTime = false
			}
			
			delta = audioDelta
		}
		
		// adjust sample buffer times to account for pauses
		if CMTimeGetSeconds(delta) > 0 {
			// do adjustment
			var count: CMItemCount = 0
			CMSampleBufferGetSampleTimingInfoArray(sampleBuffer, 0, nil, &count)
			
			var timingInfo: [CMSampleTimingInfo] = []
			
			for var i: CMItemCount = 0; i < count; i++ {
				timingInfo.append(CMSampleTimingInfo(duration: delta, presentationTimeStamp: delta, decodeTimeStamp: delta))
			}
			
			CMSampleBufferGetSampleTimingInfoArray(sampleBuffer, count, &timingInfo, &count)
			
			for var i: CMItemCount = 0; i < count; i++ {
				timingInfo[i].decodeTimeStamp = CMTimeSubtract(timingInfo[i].decodeTimeStamp, delta)
				timingInfo[i].presentationTimeStamp = CMTimeSubtract(timingInfo[i].presentationTimeStamp, delta)
			}
			
			var out: Unmanaged<CMSampleBuffer>? = nil
			CMSampleBufferCreateCopyWithNewTiming(nil, sampleBuffer, count, timingInfo, &out)
			
			if out != nil {
				buffer = out!.takeRetainedValue() as CMSampleBuffer
			}
			
			// update the start time of sample buffer
			start = CMTimeSubtract(start, delta)
		}
		
		// handle video write
		if type == TurboCaptureWriterMediaType.Video && videoInput!.readyForMoreMediaData {
			videoInput?.appendSampleBuffer(buffer)
			lastVideoTime = CMTimeAdd(start, CMTimeMakeWithSeconds(0.04, 1000000000))
			
			// handle audio writes
		} else if type == TurboCaptureWriterMediaType.Audio && audioInput!.readyForMoreMediaData {
			audioInput?.appendSampleBuffer(buffer)
			
			// set startTime if not yet set
			if startTime == nil {
				startTime = start
			}
			
			// determine duration and trigger delegate
			var elapsed = CMTimeSubtract(CMTimeAdd(start, duration), startTime!)
			delegate?.turboCaptureWriterElapsed(CMTimeGetSeconds(elapsed))
			
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
	
	func pause() {
		updateVideoTime = true
		updateAudioTime = true
	}
	
	private func error(message :String) {
		errorOccurred = true
		delegate?.turboCaptureWriterError(message)
	}
}
