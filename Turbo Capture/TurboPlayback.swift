//
//  TurboPlayback.swift
//  Turbo Capture
//
//  Created by Shahan Khan on 9/8/14.
//  Copyright (c) 2014 Shahan Khan. All rights reserved.
//

import UIKit
import AVFoundation

protocol TurboPlaybackDelegate {
	func turboPlaybackStopped()
	func turboPlaybackPaused()
	func turboPlaybackStarted()
	func turboPlaybackPosition(seconds :Double)
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
	var duration :Double {
		get {
			return videoDuration
		}
	}
	
	// MARK: Private Properties
	private var url :NSURL
	private var errorOccurred = false
	private var view :UIView
	private var isPlaying = false
	private var videoDuration :Double = 0.0
	private var player :AVPlayer
	private var layer :AVPlayerLayer
	
	// MARK: Init
	init(url :NSURL, view :UIView, delegate :TurboPlaybackDelegate?) {
		self.url = url
		self.view = view
		self.delegate = delegate
		
		// setup avplayer
		player = AVPlayer(URL: url)
		
		// determine video duration
		videoDuration = CMTimeGetSeconds(player.currentItem.asset.duration)
		
		// setup view
		layer = AVPlayerLayer(player: player)
		layer.frame = view.bounds
		view.layer.addSublayer(layer)
	}
	
	// MARK: Sizing
	func aspectFill() {
		layer.videoGravity = AVLayerVideoGravityResizeAspectFill
	}
	
	// MARK: Playback Lifecycle
	func play() {
		if playing || !ready {
			return
		}
		
		// nested due to swift compiler errors with type
		if player.status == AVPlayerStatus.ReadyToPlay && player.currentItem.status == AVPlayerItemStatus.ReadyToPlay {
			player.play()
			delegate?.turboPlaybackStarted()
			isPlaying = true
		}
	}
	
	func pause() {
		if !isPlaying || !ready {
			return
		}
		
		player.pause()
		
		delegate?.turboPlaybackPaused()
		isPlaying = false
	}
	
	func seek(seconds :Double) {
		var seconds2 = seconds
		
		if seconds > videoDuration {
			seconds2 = videoDuration
		}
		
		player.seekToTime(CMTimeMakeWithSeconds(seconds, player.currentTime().timescale))
	}
	
	func stop() {
		if !isPlaying || !ready {
			return
		}
		
		pause()
		seek(0)
		
		delegate?.turboPlaybackStopped()
	}
	
	private func error() {
		errorOccurred = true
	}
}
