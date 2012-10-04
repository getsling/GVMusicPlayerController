//
//  ViewController.m
//  Example
//
//  Created by Kevin Renskers on 03-10-12.
//  Copyright (c) 2012 Gangverk. All rights reserved.
//

#import "ViewController.h"
#import "GVMusicPlayerController.h"
#import "NSString+TimeToString.h"

@interface ViewController () <GVMusicPlayerControllerDelegate, MPMediaPickerControllerDelegate>
@property (weak, nonatomic) IBOutlet UILabel *songLabel;
@property (weak, nonatomic) IBOutlet UILabel *artistLabel;
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet UIButton *playPauseButton;
@property (weak, nonatomic) IBOutlet UISlider *progressSlider;
@property (weak, nonatomic) IBOutlet UISlider *volumeSlider;
@property (weak, nonatomic) IBOutlet UILabel *trackCurrentPlaybackTimeLabel;
@property (weak, nonatomic) IBOutlet UILabel *trackLengthLabel;
@property (weak, nonatomic) IBOutlet UIView *chooseView;
@property (weak, nonatomic) IBOutlet UIButton *repeatButton;
@property (weak, nonatomic) IBOutlet UIButton *shuffleButton;
@property (strong, nonatomic) NSTimer *timer;
@property BOOL panningProgress;
@property BOOL panningVolume;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [[GVMusicPlayerController sharedInstance] addDelegate:self];

    [self.view bringSubviewToFront:self.chooseView];

    self.timer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(timedJob) userInfo:nil repeats:YES];
    [self.timer fire];
}

- (void)viewDidUnload {
    [[GVMusicPlayerController sharedInstance] removeDelegate:self];
    [self setChooseView:nil];
    [super viewDidUnload];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)timedJob {
    if (!self.panningProgress) {
        self.progressSlider.value = [GVMusicPlayerController sharedInstance].currentPlaybackTime;
        self.trackCurrentPlaybackTimeLabel.text = [NSString stringFromTime:[GVMusicPlayerController sharedInstance].currentPlaybackTime];
    }
}

#pragma mark - Catch remote control events, forward to the music player

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    self.shuffleButton.selected = ([GVMusicPlayerController sharedInstance].shuffleMode != MPMusicShuffleModeOff);
    [self setCorrectRepeatButtomImage];
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
    [self becomeFirstResponder];
}

- (void)viewWillDisappear:(BOOL)animated {
    [[UIApplication sharedApplication] endReceivingRemoteControlEvents];
    [self resignFirstResponder];
    [super viewWillDisappear:animated];
}

- (BOOL)canBecomeFirstResponder {
    return YES;
}

- (void)remoteControlReceivedWithEvent:(UIEvent *)receivedEvent {
    [[GVMusicPlayerController sharedInstance] remoteControlReceivedWithEvent:receivedEvent];
}

#pragma mark - IBActions

- (IBAction)playButtonPressed {
    if ([GVMusicPlayerController sharedInstance].playbackState == MPMusicPlaybackStatePlaying) {
        [[GVMusicPlayerController sharedInstance] pause];
    } else {
        [[GVMusicPlayerController sharedInstance] play];
    }
}

- (IBAction)prevButtonPressed {
    [[GVMusicPlayerController sharedInstance] skipToPreviousItem];
}

- (IBAction)nextButtonPressed {
    [[GVMusicPlayerController sharedInstance] skipToNextItem];
}

- (IBAction)chooseButtonPressed {
    MPMediaPickerController *picker = [[MPMediaPickerController alloc] initWithMediaTypes:MPMediaTypeMusic];
    picker.delegate = self;
    picker.allowsPickingMultipleItems = YES;
    [self presentViewController:picker animated:YES completion:nil];
}

- (IBAction)volumeChanged:(UISlider *)sender {
    self.panningVolume = YES;
    [GVMusicPlayerController sharedInstance].volume = sender.value;
}

- (IBAction)volumeEnd {
    self.panningVolume = NO;
}

- (IBAction)progressChanged:(UISlider *)sender {
    // While dragging the progress slider around, we change the time label,
    // but we're not actually changing the playback time yet.
    self.panningProgress = YES;
    self.trackCurrentPlaybackTimeLabel.text = [NSString stringFromTime:sender.value];
}

- (IBAction)progressEnd {
    // Only when dragging is done, we change the playback time.
    [GVMusicPlayerController sharedInstance].currentPlaybackTime = self.progressSlider.value;
    self.panningProgress = NO;
}

- (IBAction)shuffleButtonPressed {
    self.shuffleButton.selected = !self.shuffleButton.selected;

    if (self.shuffleButton.selected) {
        [GVMusicPlayerController sharedInstance].shuffleMode = MPMusicShuffleModeSongs;
    } else {
        [GVMusicPlayerController sharedInstance].shuffleMode = MPMusicShuffleModeOff;
    }
}

- (IBAction)repeatButtonPressed {
    switch ([GVMusicPlayerController sharedInstance].repeatMode) {
        case MPMusicRepeatModeAll:
            // From all to one
            [GVMusicPlayerController sharedInstance].repeatMode = MPMusicRepeatModeOne;
            break;

        case MPMusicRepeatModeOne:
            // From one to none
            [GVMusicPlayerController sharedInstance].repeatMode = MPMusicRepeatModeNone;
            break;

        case MPMusicRepeatModeNone:
            // From none to all
            [GVMusicPlayerController sharedInstance].repeatMode = MPMusicRepeatModeAll;
            break;

        default:
            [GVMusicPlayerController sharedInstance].repeatMode = MPMusicRepeatModeAll;
            break;
    }

    [self setCorrectRepeatButtomImage];
}

- (void)setCorrectRepeatButtomImage {
    NSString *imageName;

    switch ([GVMusicPlayerController sharedInstance].repeatMode) {
        case MPMusicRepeatModeAll:
            imageName = @"Track_Repeat_On";
            break;

        case MPMusicRepeatModeOne:
            imageName = @"Track_Repeat_On_Track";
            break;

        case MPMusicRepeatModeNone:
            imageName = @"Track_Repeat_Off";
            break;

        default:
            imageName = @"Track_Repeat_Off";
            break;
    }

    [self.repeatButton setImage:[UIImage imageNamed:imageName] forState:UIControlStateNormal];
}

#pragma mark - AVMusicPlayerControllerDelegate

- (void)musicPlayer:(GVMusicPlayerController *)musicPlayer playbackStateChanged:(MPMusicPlaybackState)playbackState previousPlaybackState:(MPMusicPlaybackState)previousPlaybackState {
    self.playPauseButton.selected = (playbackState == MPMusicPlaybackStatePlaying);
}

- (void)musicPlayer:(GVMusicPlayerController *)musicPlayer trackDidChange:(MPMediaItem *)nowPlayingItem previousTrack:(MPMediaItem *)previousTrack {
    if (!nowPlayingItem) {
        self.chooseView.hidden = NO;
        return;
    }

    self.chooseView.hidden = YES;

    // Time labels
    NSTimeInterval trackLength = [[nowPlayingItem valueForProperty:MPMediaItemPropertyPlaybackDuration] doubleValue];
    self.trackLengthLabel.text = [NSString stringFromTime:trackLength];
    self.progressSlider.value = 0;
    self.progressSlider.maximumValue = trackLength;

    // Labels
    self.songLabel.text = [nowPlayingItem valueForProperty:MPMediaItemPropertyTitle];
    self.artistLabel.text = [nowPlayingItem valueForProperty:MPMediaItemPropertyArtist];

    // Artwork
    MPMediaItemArtwork *artwork = [nowPlayingItem valueForProperty:MPMediaItemPropertyArtwork];
    if (artwork != nil) {
        self.imageView.image = [artwork imageWithSize:self.imageView.frame.size];
    }

    NSLog(@"Proof that this code is being called, even in the background!");
}

- (void)musicPlayer:(GVMusicPlayerController *)musicPlayer volumeChanged:(float)volume {
    if (!self.panningVolume) {
        self.volumeSlider.value = volume;
    }
}

#pragma mark - MPMediaPickerControllerDelegate

- (void)mediaPickerDidCancel:(MPMediaPickerController *)mediaPicker {
    [mediaPicker dismissViewControllerAnimated:YES completion:nil];
}

- (void)mediaPicker:(MPMediaPickerController *)mediaPicker didPickMediaItems:(MPMediaItemCollection *)mediaItemCollection {
    [[GVMusicPlayerController sharedInstance] setQueueWithItemCollection:mediaItemCollection];
    [[GVMusicPlayerController sharedInstance] play];
    [mediaPicker dismissViewControllerAnimated:YES completion:nil];
}

@end
