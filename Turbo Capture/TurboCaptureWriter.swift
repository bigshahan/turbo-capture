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

enum 

// basically wraps AVAssetWriter with inputs
class TurboCaptureWriter: NSObject {
	var writer :AVAssetWriter
	var audioInput :AVAssetWriterInput
	var videoInput :AVAssetWriterInput
	
	init(url: NSURL) {
		var err = NSErrorPointer()
		// setyp writer
		writer = AVAssetWriter(URL: url, fileType: AVMediaTypeMuxed, error: err)
		
		// setup inputs
		audioInput = AVAssetWriterInput(mediaType: AVMediaTypeAudio, outputSettings: nil)
		videoInput = AVAssetWriterInput(mediaType: AVMediaTypeAudio, outputSettings: nil)
		
		// add inputs to AVAssetWriter
		if writer.canAddInput(audioInput) {
			writer.addInput(audioInput)
		}
		
		if writer.canAddInput(videoInput) {
			writer.addInput(videoInput)
		}
	}
	
	
}
