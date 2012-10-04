//
//  GVMusicPlayer.h
//  Example
//
//  Created by Kevin Renskers on 03-10-12.
//  Copyright (c) 2012 Gangverk. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MediaPlayer/MediaPlayer.h>

@class GVMusicPlayerController;

@protocol GVMusicPlayerControllerDelegate <NSObject>
@optional
- (void)musicPlayer:(GVMusicPlayerController *)musicPlayer trackDidChange:(MPMediaItem *)nowPlayingItem previousTrack:(MPMediaItem *)previousTrack;
- (void)musicPlayer:(GVMusicPlayerController *)musicPlayer playbackStateChanged:(MPMusicPlaybackState)playbackState previousPlaybackState:(MPMusicPlaybackState)previousPlaybackState;
- (void)musicPlayer:(GVMusicPlayerController *)musicPlayer volumeChanged:(float)volume;
@end


@interface GVMusicPlayerController : NSObject <MPMediaPlayback>

@property (strong, nonatomic, readonly) MPMediaItem *nowPlayingItem;
@property (nonatomic) MPMusicPlaybackState playbackState;
@property (nonatomic) MPMusicRepeatMode repeatMode;
@property (nonatomic) MPMusicShuffleMode shuffleMode;
@property (nonatomic) float volume;
@property (nonatomic, readonly) NSUInteger indexOfNowPlayingItem;
@property (nonatomic) BOOL updateNowPlayingCenter;

+ (GVMusicPlayerController *)sharedInstance;

- (void)addDelegate:(id<GVMusicPlayerControllerDelegate>)delegate;
- (void)removeDelegate:(id<GVMusicPlayerControllerDelegate>)delegate;
- (void)remoteControlReceivedWithEvent:(UIEvent *)receivedEvent;
- (void)setQueueWithItemCollection:(MPMediaItemCollection *)itemCollection;
- (void)setQueueWithQuery:(MPMediaQuery *)query;
- (void)skipToNextItem;
- (void)skipToBeginning;
- (void)skipToPreviousItem;

@end
