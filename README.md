# GVMusicPlayerController
The power of AVPlayer with the simplicity of MPMusicPlayerController.

## The problem
You want to play music from the iPod library in your app. There are some possible ways to do this:

### MPMusicPlayerController
Use MPMusicPlayerController. Easy to use, just give it a media query or media collection and you're done. It's easy to get notified about playback state and track changes, remote control events work and the now playing center is automatically updated. 

However, notifications don't work while the app is in the background and your app icon won't show up in the multitasking bar. Setting up notification listeners is also a bit of a pain, there are no delegate methods.

### AVPlayer
A more powerful way is AVPlayer. You can execute code in the background and your app icon will show up in the multitasking bar.

However, it doesn't work with media queries or media collections. It doesn't know anything about queues, repeat modes and shuffling. By itself, it doesn't send notifications about track changes. And last but not least, it's a lot more complicated to set it all up: handling the now playing center, listening to remote control events, etc.

## The solution
GVMusicPlayerController brings the simplicity and most of the API of MPMusicPlayerController, but playback happens with AVPlayer, giving all the power you need.

### Example
Handling a MPMediaPickerController with just two changed letters!

```
- (void)mediaPicker:(MPMediaPickerController *)mediaPicker didPickMediaItems:(MPMediaItemCollection *)mediaItemCollection {
    [[GVMusicPlayerController sharedInstance] setQueueWithItemCollection:mediaItemCollection];
    [mediaPicker dismissViewControllerAnimated:YES completion:nil];
}
```

Better delegate callbacks:

```
- (void)viewDidLoad {
    [super viewDidLoad];
    [[GVMusicPlayerController sharedInstance] addDelegate:self];
}

- (void)viewDidUnload {
    [[GVMusicPlayerController sharedInstance] removeDelegate:self];
    [super viewDidUnload];
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


## Installation
The best and easiest way is to use [CocoaPods](http://cocoapods.org).

### Alternatives
Not using CocoaPods?

1. Get the code: `git clone git://github.com/gangverk/GVMusicPlayerController.git`
2. Drag the `GVMusicPlayerController ` subfolder to your project. Check both "copy items into destination group's folder" and your target.

Alternatively you can add this code as a Git submodule:

1. `cd [your project root]`
2. `git submodule add git://github.com/gangverk/GVMusicPlayerController.git`
3. Drag the `GVMusicPlayerController ` subfolder to your project. Uncheck the "copy items into destination group's folder" box, do check your target.

### Requirements

* GVMusicPlayerController is built using ARC and modern Objective-C syntax. You will need Xcode 4.4 or higher to use it in your project.
* You need to add the following frameworks to your project (or install GVMusicPlayerController with CocoaPods): `CoreMedia`, `AudioToolbox`, `AVFoundation` and `MediaPlayer`


## Issues and questions
Have a bug? Please [create an issue on GitHub](https://github.com/gangverk/GVMusicPlayerController/issues)!


## License
GVMusicPlayerController is available under the MIT license. See the LICENSE file for more info.
