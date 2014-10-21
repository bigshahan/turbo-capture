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
	func turboPlaybackBufferingStarted()
	func turboPlaybackBufferingFinished()
	func turboPlaybackPosition(seconds: Double)
	func turboPlaybackError(message: String)
}

class TurboPlayback: TurboBase {
	// MARK: Public Properties
	var delegate: TurboPlaybackDelegate?
	var playing: Bool {
		get {
			return isPlaying
		}
	}
	var ready: Bool {
		get {
			return !errorOccurred
		}
	}
	
	var loop = false
	var buffering = false
	
	// in seconds
	var duration: Double {
		get {
			return videoDuration
		}
	}
	
	// MARK: Private Properties
	private var url: NSURL
	private var errorOccurred = false
	private var view: UIView
	private var isPlaying = false
	private var videoDuration: Double = 0.0
	private var player: AVPlayer
	private var layer: AVPlayerLayer
	private var timer: NSTimer?
	
	// MARK: Init
	init(url: NSURL, view: UIView, autoplay: Bool, delegate: TurboPlaybackDelegate?) {
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
		
		// handle autoplay
		if autoplay {
			player.addObserver(self, forKeyPath: "status", options: .New, context: nil)
			player.currentItem.addObserver(self, forKeyPath: "status", options: .New, context: nil)
		}
	}
	
	private func startObserving() {
		if player.currentItem == nil {
			return
		}
		
		player.currentItem.addObserver(self, forKeyPath: "playbackBufferEmpty", options: .New, context: nil)
		player.currentItem.addObserver(self, forKeyPath: "playbackLikelyToKeepUp", options: .New, context: nil)
	}
	
	private func stopObserving() {
		if player.currentItem == nil {
			return
		}
		
		player.currentItem.removeObserver(self, forKeyPath: "status")
		player.currentItem.removeObserver(self, forKeyPath: "playbackBufferEmpty")
		player.currentItem.removeObserver(self, forKeyPath: "playbackLikelyToKeepUp")
	}
	
	func cleanup() {
		stopObserving()
	}
	
	// MARK: - KVO Observer
	// used for autoplay
	override func observeValueForKeyPath(keyPath: String, ofObject object: AnyObject, change: [NSObject : AnyObject], context: UnsafeMutablePointer<Void>) {
		var checkBuffering = false
		
		switch keyPath {
		case "playbackBufferEmpty":
			checkBuffering = true
		case "playbackLikelyToKeepUp":
			checkBuffering = true
		default:
			if player.status == AVPlayerStatus.ReadyToPlay && player.currentItem.status == AVPlayerItemStatus.ReadyToPlay {
				play()
				player.removeObserver(self, forKeyPath: "status")
				player.currentItem.removeObserver(self, forKeyPath: "status")
			}
		}
		
		if checkBuffering {
			if player.currentItem.playbackBufferFull || player.currentItem.playbackLikelyToKeepUp {
				delegate?.turboPlaybackBufferingFinished()
				
				// resume playback
				if playing && ready {
					self.player.play()
				}
			} else {
				delegate?.turboPlaybackBufferingStarted()
			}
		}
	}
	
	// MARK: - Sizing
	func aspectFill() {
		layer.videoGravity = AVLayerVideoGravityResizeAspectFill
	}
	
	// MARK: - Playback Lifecycle
	func play() {
		if playing || !ready {
			return
		}
		
		startObserving()
		
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
		
		stopObserving()
		player.pause()
		
		delegate?.turboPlaybackPaused()
		isPlaying = false
		
		// stop timer
		timer?.invalidate()
		timer = nil
	}
	
	func seek(seconds: Double) {
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
		
		main({
			self.delegate?.turboPlaybackStopped()
			return
		})
		
		if loop {
			play()
		}
	}
	
	private func error(message :String) {
		errorOccurred = true
		
		main({
			self.delegate?.turboPlaybackError(message)
			return
		})
	}
	
	func playedSplitSecond() {
		main({
			self.delegate?.turboPlaybackPosition(CMTimeGetSeconds(self.player.currentTime()))
			return
		})
	}
}
