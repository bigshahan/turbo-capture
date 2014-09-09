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

class TurboPlayback: TurboBase {
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
	
	var loop = false
	
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
	private var timer :NSTimer?
	
	// MARK: Init
	init(url :NSURL, view :UIView, autoplay :Bool, delegate :TurboPlaybackDelegate?) {
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
		
		// setup notification listener
		super.init()
		NSNotificationCenter.defaultCenter().addObserver(self, selector: "stop", name: AVPlayerItemDidPlayToEndTimeNotification, object: player.currentItem)
		
		if autoplay {
			while(true) {
				if playing {
					break
				}
				
				if player.status == AVPlayerStatus.Failed {
					break
				}
				
				if player.currentItem.status == AVPlayerItemStatus.Failed {
					break
				}
				
				play()
			}
			
		}
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
			
			self.isPlaying = true
			self.delegate?.turboPlaybackStarted()
			self.player.play()

			// start timer
			timer = NSTimer.scheduledTimerWithTimeInterval(0.25, target: self, selector: "playedSplitSecond", userInfo: nil, repeats: true)
		}
	}
	
	func pause() {
		if !isPlaying || !ready {
			return
		}
		
		player.pause()
		
		delegate?.turboPlaybackPaused()
		isPlaying = false
		
		// stop timer
		timer?.invalidate()
		timer = nil
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
		
		if loop {
			play()
		}
		
		delegate?.turboPlaybackStopped()
	}
	
	private func error(message :String) {
		errorOccurred = true
		
		async({
			self.delegate?.turboPlaybackError(message)
			return
		})
	}
	
	func playedSplitSecond() {
		async({
			self.delegate?.turboPlaybackPosition(CMTimeGetSeconds(self.player.currentTime()))
			return
		})
	}
}
