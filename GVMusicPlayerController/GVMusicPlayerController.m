//
//  GVMusicPlayer.m
//  Example
//
//  Created by Kevin Renskers on 03-10-12.
//  Copyright (c) 2012 Gangverk. All rights reserved.
//

#import "GVMusicPlayerController.h"
#import <AVFoundation/AVFoundation.h>


@interface NSArray (GVShuffledArray)
- (NSArray *)shuffled;
@end

@implementation NSArray (GVShuffledArray)

- (NSArray *)shuffled {
	NSMutableArray *tmpArray = [NSMutableArray arrayWithCapacity:[self count]];

	for (id anObject in self) {
		NSUInteger randomPos = arc4random()%([tmpArray count]+1);
		[tmpArray insertObject:anObject atIndex:randomPos];
	}

	return [NSArray arrayWithArray:tmpArray];
}

@end


@interface GVMusicPlayerController () <AVAudioSessionDelegate>
@property (copy, nonatomic) NSArray *delegates;
@property (strong, nonatomic) AVPlayer *player;
@property (strong, nonatomic) NSArray *originalQueue;
@property (strong, nonatomic, readwrite) NSArray *queue;
@property (strong, nonatomic, readwrite) MPMediaItem *nowPlayingItem;
@property (nonatomic, readwrite) NSUInteger indexOfNowPlayingItem;
@property (nonatomic) BOOL interrupted;
@property (nonatomic) BOOL isLoadingAsset;
@end

@implementation GVMusicPlayerController

@synthesize isPreparedToPlay = _isPreparedToPlay;
@synthesize currentPlaybackTime = _currentPlaybackTime;
@synthesize currentPlaybackRate = _currentPlaybackRate;

+ (GVMusicPlayerController *)sharedInstance {
    static dispatch_once_t onceQueue;
    static GVMusicPlayerController *instance = nil;
    dispatch_once(&onceQueue, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

void audioRouteChangeListenerCallback (void *inUserData, AudioSessionPropertyID inPropertyID, UInt32 inPropertyValueSize, const void *inPropertyValue) {
    if (inPropertyID != kAudioSessionProperty_AudioRouteChange) return;

    GVMusicPlayerController *controller = (__bridge GVMusicPlayerController *)inUserData;

    CFDictionaryRef routeChangeDictionary = inPropertyValue;

    CFNumberRef routeChangeReasonRef = CFDictionaryGetValue(routeChangeDictionary, CFSTR (kAudioSession_AudioRouteChangeKey_Reason));
    SInt32 routeChangeReason;
    CFNumberGetValue (routeChangeReasonRef, kCFNumberSInt32Type, &routeChangeReason);

    CFStringRef oldRouteRef = CFDictionaryGetValue(routeChangeDictionary, CFSTR (kAudioSession_AudioRouteChangeKey_OldRoute));
    NSString *oldRouteString = (__bridge NSString *)oldRouteRef;

    if (routeChangeReason == kAudioSessionRouteChangeReason_OldDeviceUnavailable) {
        if ((controller.playbackState == MPMusicPlaybackStatePlaying) &&
            (([oldRouteString isEqualToString:@"Headphone"]) ||
             ([oldRouteString isEqualToString:@"LineOut"])))
        {
            // Janking out the headphone will stop the audio.
            [controller pause];
        }
    }
}

- (id)init {
    self = [super init];
    if (self) {
        self.indexOfNowPlayingItem = NSNotFound;
        self.delegates = [NSArray array];

        // Set defaults
        self.updateNowPlayingCenter = YES;
        self.repeatMode = MPMusicRepeatModeNone;
        self.shuffleMode = MPMusicShuffleModeOff;
        self.shouldReturnToBeginningWhenSkippingToPreviousItem = YES;

        // Make sure the system follows our playback status
        AVAudioSession *audioSession = [AVAudioSession sharedInstance];
        NSError *sessionError = nil;
        BOOL success = [audioSession setCategory:AVAudioSessionCategoryPlayback error:&sessionError];
        if (!success){
            NSLog(@"setCategory error %@", sessionError);
        }
        success = [audioSession setActive:YES error:&sessionError];
        if (!success){
            NSLog(@"setActive error %@", sessionError);
        }
        [audioSession setDelegate:self];

        // Handle unplugging of headphones
        AudioSessionAddPropertyListener (kAudioSessionProperty_AudioRouteChange, audioRouteChangeListenerCallback, (__bridge void*)self);

        // Listen for volume changes
        [[MPMusicPlayerController iPodMusicPlayer] beginGeneratingPlaybackNotifications];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handle_VolumeChanged:)
                                                     name:MPMusicPlayerControllerVolumeDidChangeNotification
                                                   object:[MPMusicPlayerController iPodMusicPlayer]];
    }

    return self;
}

- (void)dealloc {
    [[MPMusicPlayerController iPodMusicPlayer] endGeneratingPlaybackNotifications];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                  name:MPMusicPlayerControllerVolumeDidChangeNotification
                                object:[MPMusicPlayerController iPodMusicPlayer]];
}

- (void)addDelegate:(id<GVMusicPlayerControllerDelegate>)delegate {
    NSMutableArray *delegates = [self.delegates mutableCopy];
    [delegates addObject:delegate];
    self.delegates = delegates;

    // Call the delegate's xChanged methods, so it can initialize its UI

    if ([delegate respondsToSelector:@selector(musicPlayer:trackDidChange:previousTrack:)]) {
        [delegate musicPlayer:self trackDidChange:self.nowPlayingItem previousTrack:nil];
    }

    if ([delegate respondsToSelector:@selector(musicPlayer:playbackStateChanged:previousPlaybackState:)]) {
        [delegate musicPlayer:self playbackStateChanged:self.playbackState previousPlaybackState:MPMusicPlaybackStateStopped];
    }

    if ([delegate respondsToSelector:@selector(musicPlayer:volumeChanged:)]) {
        [delegate musicPlayer:self volumeChanged:self.volume];
    }
    
    if ([delegate respondsToSelector:@selector(musicPlayer:endOfQueueReached:)]) {
        [delegate musicPlayer:self endOfQueueReached:self.nowPlayingItem];
    }
}

- (void)removeDelegate:(id<GVMusicPlayerControllerDelegate>)delegate {
    NSMutableArray *delegates = [self.delegates mutableCopy];
    [delegates removeObject:delegate];
    self.delegates = delegates;
}

#pragma mark - Emulate MPMusicPlayerController

- (void)setQueueWithItemCollection:(MPMediaItemCollection *)itemCollection {
    self.originalQueue = [itemCollection items];
}

- (void)setQueueWithQuery:(MPMediaQuery *)query {
    self.originalQueue = [query items];
}

- (void)skipToNextItem {
    if (self.indexOfNowPlayingItem+1 < [self.queue count]) {
        // Play next track
        self.indexOfNowPlayingItem++;
    } else {
        if (self.repeatMode == MPMusicRepeatModeAll) {
            // Wrap around back to the first track
            self.indexOfNowPlayingItem = 0;
        } else {
            if (self.playbackState == MPMusicPlaybackStatePlaying) {
                if (_nowPlayingItem != nil) {
                    for (id <GVMusicPlayerControllerDelegate> delegate in self.delegates) {
                        if ([delegate respondsToSelector:@selector(musicPlayer:endOfQueueReached:)]) {
                            [delegate musicPlayer:self endOfQueueReached:_nowPlayingItem];
                        }
                    }
                }
            }
            NSLog(@"GVMusicPlayerController: end of queue reached");
            [self stop];
        }
    }
}

- (void)skipToBeginning {
    self.currentPlaybackTime = 0.0;
}

- (void)skipToPreviousItem {
    if (self.indexOfNowPlayingItem > 0) {
        self.indexOfNowPlayingItem--;
    } else if (self.shouldReturnToBeginningWhenSkippingToPreviousItem) {
        [self skipToBeginning];
    }
}

#pragma mark - MPMediaPlayback

- (void)play {
    [self.player play];
    self.playbackState = MPMusicPlaybackStatePlaying;
}

- (void)pause {
    [self.player pause];
    self.playbackState = MPMusicPlaybackStatePaused;
}

- (void)stop {
    [self.player pause];
    self.playbackState = MPMusicPlaybackStateStopped;
}

- (void)prepareToPlay {
    NSLog(@"Not supported");
}

- (void)beginSeekingBackward {
    NSLog(@"Not supported");
}

- (void)beginSeekingForward {
    NSLog(@"Not supported");
}

- (void)endSeeking {
    NSLog(@"Not supported");
}

- (BOOL)isPreparedToPlay {
    return YES;
}

- (NSTimeInterval)currentPlaybackTime {
#if !(TARGET_IPHONE_SIMULATOR)
    return self.player.currentTime.value / self.player.currentTime.timescale;
#else
    return 0;
#endif
}

- (void)setCurrentPlaybackTime:(NSTimeInterval)currentPlaybackTime {
    CMTime t = CMTimeMake(currentPlaybackTime, 1);
    [self.player seekToTime:t];
}

- (float)currentPlaybackRate {
    return self.player.rate;
}

- (void)setCurrentPlaybackRate:(float)currentPlaybackRate {
    self.player.rate = currentPlaybackRate;
}

#pragma mark - Setters and getters

- (void)setShuffleMode:(MPMusicShuffleMode)shuffleMode {
    _shuffleMode = shuffleMode;
    self.queue = self.originalQueue;
}

- (float)volume {
    return [MPMusicPlayerController iPodMusicPlayer].volume;
}

- (void)setVolume:(float)volume {
    [MPMusicPlayerController iPodMusicPlayer].volume = volume;
    for (id <GVMusicPlayerControllerDelegate> delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(musicPlayer:volumeChanged:)]) {
            [delegate musicPlayer:self volumeChanged:volume];
        }
    }
}

- (void)setOriginalQueue:(NSArray *)originalQueue {
    // The original queue never changes, while queue is shuffled
    _originalQueue = originalQueue;
    self.queue = originalQueue;
}

- (void)setQueue:(NSArray *)queue {
    switch (self.shuffleMode) {
        case MPMusicShuffleModeOff:
            _queue = queue;
            break;

        case MPMusicShuffleModeSongs:
            _queue = [queue shuffled];
            break;

        default:
            NSLog(@"Only MPMusicShuffleModeOff and MPMusicShuffleModeSongs are supported");
            _queue = [queue shuffled];
            break;
    }

    if ([_queue count]) {
        self.indexOfNowPlayingItem = 0;
    } else {
        self.indexOfNowPlayingItem = NSNotFound;
    }
}

- (void)setIndexOfNowPlayingItem:(NSUInteger)indexOfNowPlayingItem {
    if (indexOfNowPlayingItem == NSNotFound) {
        return;
    }

    _indexOfNowPlayingItem = indexOfNowPlayingItem;
    self.nowPlayingItem = [self.queue objectAtIndex:indexOfNowPlayingItem];
}

- (void)setNowPlayingItem:(MPMediaItem *)nowPlayingItem {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:nil];

    MPMediaItem *previousTrack = _nowPlayingItem;
    _nowPlayingItem = nowPlayingItem;

    // Used to prevent duplicate notifications
    self.isLoadingAsset = YES;

    // Create a new player item
    NSURL *assetUrl = [nowPlayingItem valueForProperty:MPMediaItemPropertyAssetURL];
    AVPlayerItem *playerItem = [AVPlayerItem playerItemWithURL:assetUrl];

    // Either create a player or replace it
    if (self.player) {
        [self.player replaceCurrentItemWithPlayerItem:playerItem];
    } else {
        self.player = [AVPlayer playerWithPlayerItem:playerItem];
    }

    // Subscribe to the AVPlayerItem's DidPlayToEndTime notification.
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleAVPlayerItemDidPlayToEndTimeNotification) name:AVPlayerItemDidPlayToEndTimeNotification object:nil];

    // Inform delegates
    for (id <GVMusicPlayerControllerDelegate> delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(musicPlayer:trackDidChange:previousTrack:)]) {
            [delegate musicPlayer:self trackDidChange:nowPlayingItem previousTrack:previousTrack];
        }
    }

    // Inform iOS now playing center
    [self doUpdateNowPlayingCenter];

    self.isLoadingAsset = NO;
}

- (void)playItemAtIndex:(NSUInteger)index {
    [self setIndexOfNowPlayingItem:index];
}

- (void)playItem:(MPMediaItem *)item {
    NSUInteger indexOfItem = [self.queue indexOfObject:item];
    [self playItemAtIndex:indexOfItem];
}

- (void)handleAVPlayerItemDidPlayToEndTimeNotification {
    if (!self.isLoadingAsset) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.repeatMode == MPMusicRepeatModeOne) {
                // Play the same track again
                self.indexOfNowPlayingItem = self.indexOfNowPlayingItem;
                if (self.playbackState == MPMusicPlaybackStatePlaying) {
                    [self.player play];
                }
            } else {
                // Go to next track
                [self skipToNextItem];
                if (self.playbackState == MPMusicPlaybackStatePlaying) {
                    [self.player play];
                }
            }
        });
    }
}

- (void)doUpdateNowPlayingCenter {
    if (!self.updateNowPlayingCenter || !self.nowPlayingItem) {
        return;
    }

    // Only available on iOS 5
    Class playingInfoCenter = NSClassFromString(@"MPNowPlayingInfoCenter");
    if (!playingInfoCenter) {
        return;
    }

    MPNowPlayingInfoCenter *center = [playingInfoCenter defaultCenter];

    NSMutableDictionary *songInfo = [NSMutableDictionary dictionaryWithDictionary:@{
        MPMediaItemPropertyArtist: [self.nowPlayingItem valueForProperty:MPMediaItemPropertyArtist] ?: @"",
        MPMediaItemPropertyTitle: [self.nowPlayingItem valueForProperty:MPMediaItemPropertyTitle] ?: @"",
        MPMediaItemPropertyAlbumTitle: [self.nowPlayingItem valueForProperty:MPMediaItemPropertyAlbumTitle] ?: @"",
        MPMediaItemPropertyPlaybackDuration: [self.nowPlayingItem valueForProperty:MPMediaItemPropertyPlaybackDuration] ?: @0
    }];

    // Add the artwork if it exists
    MPMediaItemArtwork *artwork = [self.nowPlayingItem valueForProperty:MPMediaItemPropertyArtwork];
    if (artwork) {
        [songInfo setObject:artwork forKey:MPMediaItemPropertyArtwork];
    }

    center.nowPlayingInfo = songInfo;
}

- (void)setPlaybackState:(MPMusicPlaybackState)playbackState {
    if (playbackState == _playbackState) {
        return;
    }

    for (id <GVMusicPlayerControllerDelegate> delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(musicPlayer:playbackStateChanged:previousPlaybackState:)]) {
            [delegate musicPlayer:self playbackStateChanged:playbackState previousPlaybackState:_playbackState];
        }
    }

    _playbackState = playbackState;
}

- (void)handle_VolumeChanged:(NSNotification *)notification {
    for (id <GVMusicPlayerControllerDelegate> delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(musicPlayer:volumeChanged:)]) {
            [delegate musicPlayer:self volumeChanged:[MPMusicPlayerController iPodMusicPlayer].volume];
        }
    }
}

#pragma mark - AVAudioSessionDelegate

- (void)beginInterruption {
    if (self.playbackState == MPMusicPlaybackStatePlaying) {
        self.interrupted = YES;
    }
    [self pause];
}

- (void)endInterruptionWithFlags:(NSUInteger)flags {
    if (self.interrupted && (flags & AVAudioSessionInterruptionFlags_ShouldResume)) {
        [self play];
    }
    self.interrupted = NO;
}

#pragma mark - Other public methods

- (void)remoteControlReceivedWithEvent:(UIEvent *)receivedEvent {
    if (receivedEvent.type != UIEventTypeRemoteControl) {
        return;
    }

    switch (receivedEvent.subtype) {
        case UIEventSubtypeRemoteControlTogglePlayPause: {
            if (self.playbackState == MPMusicPlaybackStatePlaying) {
                [self pause];
            } else {
                [self play];
            }
            break;
        }

        case UIEventSubtypeRemoteControlNextTrack:
            [self skipToNextItem];
            break;

        case UIEventSubtypeRemoteControlPreviousTrack:
            [self skipToPreviousItem];
            break;

        case UIEventSubtypeRemoteControlPlay:
            [self play];
            break;

        case UIEventSubtypeRemoteControlPause:
            [self pause];
            break;

        case UIEventSubtypeRemoteControlStop:
            [self stop];
            break;

        case UIEventSubtypeRemoteControlBeginSeekingBackward:
            [self beginSeekingBackward];
            break;

        case UIEventSubtypeRemoteControlBeginSeekingForward:
            [self beginSeekingForward];
            break;

        case UIEventSubtypeRemoteControlEndSeekingBackward:
        case UIEventSubtypeRemoteControlEndSeekingForward:
            [self endSeeking];
            break;

        default:
            break;
    }
}

@end
