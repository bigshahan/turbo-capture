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
	private var player: AVQueuePlayer
	private var playerItem: AVPlayerItem
	private var layer: AVPlayerLayer
	private var timer: NSTimer?
	
	private var hasStatusObserver = false
	private var hasStopObserver = false
	private var hasPlaybackBufferEmptyObserver = false
	private var hasPlaybackLikelyToKeepUpObserver = false
	
	// MARK: Init
	init(url: NSURL, view: UIView, autoplay: Bool, delegate: TurboPlaybackDelegate?) {
		self.url = url
		self.view = view
		self.delegate = delegate
		
		// setup avplayer
		player = AVQueuePlayer()
		playerItem = AVPlayerItem()
		
		// setup view
		layer = AVPlayerLayer(player: player)
		layer.frame = view.bounds
		view.layer.addSublayer(layer)
		
		// super init so can use self
		super.init()
		
		// load on sep thread the requested video
		var asset = AVURLAsset(URL: url, options: nil)
		var keys = ["playable"]
		asset.loadValuesAsynchronouslyForKeys(keys, completionHandler: {
			self.main({
				self.playerItem = AVPlayerItem(asset: asset)
				self.player.insertItem(self.playerItem, afterItem: nil)
				self.videoDuration = CMTimeGetSeconds(self.player.currentItem.asset.duration)
				
				// handle autoplay
				if autoplay {
					self.hasStatusObserver = true
					self.player.addObserver(self, forKeyPath: "status", options: .New, context: nil)
					self.playerItem.addObserver(self, forKeyPath: "status", options: .New, context: nil)
				}
			})
		})
	}
	
	private func startObserving() {
		if player.currentItem == nil {
			return
		}

		if !hasStopObserver {
			hasStopObserver = true
			NSNotificationCenter.defaultCenter().addObserver(self, selector: "playbackReachedEnd", name: AVPlayerItemDidPlayToEndTimeNotification, object: player.currentItem)
		}
		
		if !hasPlaybackBufferEmptyObserver {
			hasPlaybackBufferEmptyObserver = true
			player.currentItem.addObserver(self, forKeyPath: "playbackBufferEmpty", options: .New, context: nil)
		}
		
		if !hasPlaybackLikelyToKeepUpObserver {
			hasPlaybackLikelyToKeepUpObserver = true
			player.currentItem.addObserver(self, forKeyPath: "playbackLikelyToKeepUp", options: .New, context: nil)
		}
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
			self.player.play()
			self.delegate?.turboPlaybackStarted()

			// start timer
			timer = NSTimer.scheduledTimerWithTimeInterval(0.25, target: self, selector: "playedSplitSecond", userInfo: nil, repeats: true)
		}
	}
	
	func pause() {
		println("about to run pause functionin TurboPlayback")

		if !isPlaying || !ready {
			return
		}
		
		println("about to pause")
		player.pause()
		
		println("about to call pause delegate")
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
		
		main({
			self.delegate?.turboPlaybackStopped()
			return
		})
	}
	
	func playbackReachedEnd() {
		isPlaying = false
		player.removeAllItems()
		player.insertItem(playerItem, afterItem: nil)
		seek(0)
		
		if loop {
			play()
		} else {
			main({
				self.delegate?.turboPlaybackStopped()
				return
			})
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
	
	deinit {
		if player.currentItem == nil {
			return
		}
		
		println("about to stop observers if needed")
		
		if hasStopObserver {
			hasStopObserver = false
			println("removing stop observer")
			NSNotificationCenter.defaultCenter().removeObserver(self, name: AVPlayerItemDidPlayToEndTimeNotification, object: playerItem)
		}
		
		if hasStatusObserver {
			hasStatusObserver = false
			println("removing status observer")
			player.currentItem.removeObserver(self, forKeyPath: "status")
		}
		
		if hasPlaybackBufferEmptyObserver {
			hasPlaybackBufferEmptyObserver = false
			println("removing playbackBufferEmpty observer")
			player.currentItem.removeObserver(self, forKeyPath: "playbackBufferEmpty")
		}
		
		if hasPlaybackLikelyToKeepUpObserver {
			hasPlaybackLikelyToKeepUpObserver = false
			println("removing playbackLikelyToKeepUp observer")
			player.currentItem.removeObserver(self, forKeyPath: "playbackLikelyToKeepUp")
			
		}
	}
}
