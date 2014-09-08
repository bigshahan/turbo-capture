//
//  TurboPlayback.swift
//  Turbo Capture
//
//  Created by Shahan Khan on 9/8/14.
//  Copyright (c) 2014 Shahan Khan. All rights reserved.
//

import UIKit

protocol TurboPlaybackDelegate {
	func turboPlaybackStopped()
	func turboPlaybackPaused()
	func turboPlaybackStarted()
	func turboPlaybackPosition(seconds :Float)
	func turboPlaybackError(message :String)
}

class TurboPlayback: NSObject {
	// MARK: Public Properties
	var delegate :TurboPlaybackDelegate?
	var playing :Bool {
		get {
			return isPlaying
		}
	}
	var ready :Bool {
		get {
			return !errorOccurred
		}
	}
	// in seconds
	var duration :Float {
		get {
			return videoDuration
		}
	}
	
	// MARK: Private Properties
	private var url :NSURL?
	private var errorOccurred = false
	private var view :UIView?
	private var isPlaying = false
	private var videoDuration :Float = 0.0
	
	// MARK: Init
	init(url :NSURL, view :UIView, delegate :TurboPlaybackDelegate?) {
		self.url = url
		self.view = view
		self.delegate = delegate
		
		// setup avplayer
		
		
		// determine video duration
		
		
		// setup view
		
	}
	
	// MARK: Playback Lifecycle
	func play() {
		if playing || !ready {
			return
		}
		
		delegate?.turboPlaybackStarted()
		isPlaying = true
	}
	
	func pause() {
		if !isPlaying || !ready {
			return
		}
		
		delegate?.turboPlaybackPaused()
		isPlaying = false
	}
	
	func stop() {
		if !isPlaying || !ready {
			return
		}
		
		delegate?.turboPlaybackStopped()
	}
	
	private func error() {
		errorOccurred = true
	}
}
