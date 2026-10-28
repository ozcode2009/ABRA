//
//  MusicController.swift
//  ABRA
//
//  Created by Oliver Crumrine on 7/22/24.
//

import Foundation
import MediaPlayer
import Combine

@MainActor
class MusicCoordinator: ObservableObject {
    static let shared = MusicCoordinator();
    let player = MPMusicPlayerController.systemMusicPlayer;
    
    @Published var songName = "Not Playing"
    @Published var isPlaying: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    
    init(){
        setupNotifications()
        updateNowPlayingItem()
        updatePlaybackState()
    }
    
    func pause() {
        player.pause()
    }
    func play() {
        player.play()
    }
    func skip(){
        player.skipToNextItem();
    }
    func getPlaying() -> Bool {
        if(player.playbackState == .playing){
            return true;
        }else{
            return false;
        }
    }
    private func setupNotifications() {
        NotificationCenter.default.publisher(for: .MPMusicPlayerControllerNowPlayingItemDidChange)
            .sink { [weak self] _ in
                self?.updateNowPlayingItem()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .MPMusicPlayerControllerPlaybackStateDidChange)
            .sink { [weak self] _ in
                self?.updatePlaybackState()
            }
            .store(in: &cancellables)
        
        player.beginGeneratingPlaybackNotifications()
    }
    
    private func updateNowPlayingItem() {
        if player.playbackState != .paused && player.playbackState != .playing {
            songName = "Not Playing"
            return
        }
        if let nowPlayingItem = player.nowPlayingItem {
            songName = nowPlayingItem.title ?? "Unknown Title"
        } else {
            songName = "Not Playing"
        }
    }
    
    private func updatePlaybackState() {
        updateNowPlayingItem();
        isPlaying = player.playbackState == .playing
    }
    
    deinit {
        player.endGeneratingPlaybackNotifications()
    }
}
