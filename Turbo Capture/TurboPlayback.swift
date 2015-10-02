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
	private var playerItem: AVPlayerItem!
	private var layer: AVPlayerLayer
	private var timer: NSTimer?
	private var autoplay = false
	
	private var hasStatusObserver = false
	private var hasStopObserver = false
	private var hasPlaybackBufferEmptyObserver = false
	private var hasPlaybackLikelyToKeepUpObserver = false
	
	// MARK: Init
	init(url: NSURL, view: UIView, autoplay: Bool, delegate: TurboPlaybackDelegate?) {
		self.url = url
		self.view = view
		self.delegate = delegate
		self.autoplay = autoplay
		
		// setup avplayer
		player = AVQueuePlayer()
		
		// setup view
		layer = AVPlayerLayer(player: player)
		layer.frame = view.bounds
		view.layer.addSublayer(layer)
		
		// super init so can use self
		super.init()
		
		// load on sep thread the requested video
		let asset = AVURLAsset(URL: url, options: nil)
		let keys = ["playable"]
		asset.loadValuesAsynchronouslyForKeys(keys, completionHandler: {
			self.main({
				self.playerItem = AVPlayerItem(asset: asset)
				self.player.insertItem(self.playerItem, afterItem: nil)
				self.videoDuration = CMTimeGetSeconds(self.playerItem.asset.duration)
				
				// handle autoplay
				if self.autoplay {
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
			NSNotificationCenter.defaultCenter().addObserver(self, selector: "playbackReachedEnd", name: AVPlayerItemDidPlayToEndTimeNotification, object: playerItem)
		}
		
		if !hasPlaybackBufferEmptyObserver {
			hasPlaybackBufferEmptyObserver = true
			playerItem.addObserver(self, forKeyPath: "playbackBufferEmpty", options: .New, context: nil)
		}
		
		if !hasPlaybackLikelyToKeepUpObserver {
			hasPlaybackLikelyToKeepUpObserver = true
			playerItem.addObserver(self, forKeyPath: "playbackLikelyToKeepUp", options: .New, context: nil)
		}
	}
	
	// MARK: - KVO Observer
	// used for autoplay
	override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
		var checkBuffering = false
        
        if keyPath == nil {
            return
        }
		
		switch keyPath! {
		case "playbackBufferEmpty":
			checkBuffering = true
		case "playbackLikelyToKeepUp":
			checkBuffering = true
		default:
            if player.currentItem == nil {
                return
            }
            
			if player.status == AVPlayerStatus.ReadyToPlay && player.currentItem!.status == AVPlayerItemStatus.ReadyToPlay {
				hasStatusObserver = false
				player.removeObserver(self, forKeyPath: "status")
				playerItem.removeObserver(self, forKeyPath: "status")
				
				if autoplay {
					play()
					autoplay = false
				}
			}
		}
		
		if checkBuffering {
			if player.currentItem != nil && player.currentItem!.playbackBufferFull || player.currentItem!.playbackLikelyToKeepUp {
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
		if player.status == AVPlayerStatus.ReadyToPlay && player.currentItem != nil && player.currentItem!.status == AVPlayerItemStatus.ReadyToPlay {
			self.isPlaying = true
			self.player.play()
			self.delegate?.turboPlaybackStarted()
			
			// start timer
			timer = NSTimer.scheduledTimerWithTimeInterval(0.25, target: self, selector: "playedSplitSecond", userInfo: nil, repeats: true)
		}
	}
	
	func pause() {
		autoplay = false
		
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
	
	func seek(seconds: Double) {
		var seconds2 = seconds
		
		if seconds > videoDuration {
			seconds2 = videoDuration
		}
		
		player.seekToTime(CMTimeMakeWithSeconds(seconds, player.currentTime().timescale))
	}
	
	func stop() {
		autoplay = false
		
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
		player.pause()
		
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
		if hasStopObserver {
			hasStopObserver = false
			NSNotificationCenter.defaultCenter().removeObserver(self, name: AVPlayerItemDidPlayToEndTimeNotification, object: playerItem)
		}
		
		if hasStatusObserver {
			hasStatusObserver = false
			player.removeObserver(self, forKeyPath: "status")
			playerItem.removeObserver(self, forKeyPath: "status")
		}
		
		if hasPlaybackBufferEmptyObserver {
			hasPlaybackBufferEmptyObserver = false
			playerItem.removeObserver(self, forKeyPath: "playbackBufferEmpty")
		}
		
		if hasPlaybackLikelyToKeepUpObserver {
			hasPlaybackLikelyToKeepUpObserver = false
			playerItem.removeObserver(self, forKeyPath: "playbackLikelyToKeepUp")
			
		}
	}
}
