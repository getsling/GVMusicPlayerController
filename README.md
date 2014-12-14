# GVMusicPlayerController

[![Badge w/ Version](https://cocoapod-badges.herokuapp.com/v/GVMusicPlayerController/badge.png)](http://cocoadocs.org/docsets/GVMusicPlayerController)
[![Badge w/ Platform](https://cocoapod-badges.herokuapp.com/p/GVMusicPlayerController/badge.svg)](http://cocoadocs.org/docsets/GVMusicPlayerController)

The power of AVPlayer with the simplicity of MPMusicPlayerController.

## The problem
So, you want to play music from the iPod library in your app. There are simply speaking two possible ways to do this:

**MPMusicPlayerController**  
Use MPMusicPlayerController. Easy to use, just give it a media query or media collection and you're done. It's easy to get notified about playback state and track changes, remote control events work and the now playing center is automatically updated. Shuffling and repeat modes work like you would expect, and music in iCloud (iTunes Match) works just fine.

However, notifications don't work while the app is in the background and your app icon won't show up in the multitasking bar. If you don't need this, MPMusicPlayerController will serve you just fine.

**AVPlayer**  
A more powerful way is to go with AVPlayer. You can execute code in the background and your app icon will show up in the multitasking bar.

However, it doesn't work with media queries or media collections. It doesn't know anything about queues, repeat modes and shuffling. By itself, it doesn't send notifications about track changes. And last but not least, it's a lot more complicated to set it all up: handling the now playing center, listening to remote control events, handling audio route changes, etc.

**AVAudioPlayer**  
This class doesn't work with iPod library items, so unless you want to copy audio files to your app sandbox, it's a no-go.

## The solution
GVMusicPlayerController marries the simplicity and API of MPMusicPlayerController with the playback power of AVPlayer, giving you background delegate methods and your app icon in the multitasking bar.

### The catch
What's the catch, I hear you ask? Sadly, AVPlayer can't play music that's in iCloud or anything with DRM. This may be a major deal breaker for you.

### Examples
Handling a MPMediaPickerController is almost the same!

```
- (void)mediaPicker:(MPMediaPickerController *)mediaPicker didPickMediaItems:(MPMediaItemCollection *)mediaItemCollection {
    [[GVMusicPlayerController sharedInstance] setQueueWithItemCollection:mediaItemCollection];
    [mediaPicker dismissViewControllerAnimated:YES completion:nil];
}
```

Better delegate callbacks, that will be called while the app is in the background:

```
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [[GVMusicPlayerController sharedInstance] addDelegate:self];
}

- (void)viewDidDisappear:(BOOL)animated {
    [[GVMusicPlayerController sharedInstance] removeDelegate:self];
    [super viewDidDisappear:animated];
}

- (void)musicPlayer:(GVMusicPlayerController *)musicPlayer playbackStateChanged:(MPMusicPlaybackState)playbackState previousPlaybackState:(MPMusicPlaybackState)previousPlaybackState {
    self.playPauseButton.selected = (playbackState == MPMusicPlaybackStatePlaying);
}

- (void)musicPlayer:(GVMusicPlayerController *)musicPlayer trackDidChange:(MPMediaItem *)nowPlayingItem previousTrack:(MPMediaItem *)previousTrack {
    // Labels
    self.songLabel.text = [nowPlayingItem valueForProperty:MPMediaItemPropertyTitle];
    self.artistLabel.text = [nowPlayingItem valueForProperty:MPMediaItemPropertyArtist];

    // Artwork
    MPMediaItemArtwork *artwork = [nowPlayingItem valueForProperty:MPMediaItemPropertyArtwork];
    if (artwork != nil) {
        self.imageView.image = [artwork imageWithSize:self.imageView.frame.size];
    }
}

- (void)musicPlayer:(GVMusicPlayerController *)musicPlayer volumeChanged:(float)volume {
    self.volumeSlider.value = volume;
}
```

A complete music player app is included as an example. The example app needs iOS 5 to function due to the usage of storyboards, the library itself works on iOS 4.0 and above. Please note that the image assets in the example app are not free to use, unlike the code.

### Requirements
* iOS 5 or higher
* You need to add the following frameworks to your project (or use CocoaPods for automatic dependency handling): `CoreMedia`, `AudioToolbox`, `AVFoundation` and `MediaPlayer`


## Issues and questions
Have a bug? Please [create an issue on GitHub](https://github.com/gangverk/GVMusicPlayerController/issues)!


## License
GVMusicPlayerController is available under the MIT license. See the LICENSE file for more info.  
The image assets provided in the example app are not part of this license and can not be copied, modified or used in any way.
