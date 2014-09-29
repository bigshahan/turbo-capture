//
//  PlaybackController.swift
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

import UIKit

class PlaybackController: UIViewController, TurboPlaybackDelegate {
	// MARK: Properties
	var url: NSURL?
	var playback: TurboPlayback?
	
	// MARK: IBOutlets
	@IBOutlet weak var playbackView: UIView!
	@IBOutlet weak var progressView: UIProgressView!

	// MARK: - Handle Button Taps
	@IBAction func playPauseTapped(sender: AnyObject) {
		if playback == nil {
			return
		}
		
		if playback!.playing {
			playback?.pause()
		} else {
			playback?.play()
		}
	}
	
	// MARK: - View Controller Lifecycle
	override func viewDidLoad() {
		super.viewDidLoad()
		
		if url == nil {
			return
		}
		
		// setup of playback
		playback = TurboPlayback(url: url!, view: playbackView, autoplay: true, delegate: self)
		playback?.loop = true
		playback?.aspectFill()
	}
	
	// MARK: - Playback Delegate
	func turboPlaybackStopped() {
		progressView.setProgress(0, animated: false)
	}
	
	func turboPlaybackPaused() {
	}
	
	func turboPlaybackStarted() {
	}
	
	func turboPlaybackPosition(seconds :Double) {
		var progress = seconds/playback!.duration
		progressView.setProgress(Float(progress), animated: true)
	}
	
	func turboPlaybackError(message :String) {
		NSLog("Playback error \(message)")
		UIAlertView(title: "Error", message: "Could not playback video", delegate: nil, cancelButtonTitle: "Dismiss")
	}
}
