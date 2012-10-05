Pod::Spec.new do |s|
  s.name         = "GVMusicPlayerController"
  s.version      = "0.1.0"
  s.summary      = "The power of AVPlayer with the simplicity of MPMusicPlayerController."
  s.homepage     = "https://github.com/gangverk/GVMusicPlayerController"
  s.license      = 'MIT'
  s.author       = { "Kevin Renskers" => "info@mixedcase.nl" }
  s.source       = { :git => "https://github.com/gangverk/GVMusicPlayerController.git", :tag => "0.1.0" }
  s.ios.deployment_target = '4.0'
  s.osx.deployment_target = '10.6'
  s.source_files = 'GVMusicPlayerController/*.{h,m}'
  s.requires_arc = true
  s.frameworks   = 'CoreMedia', 'AudioToolbox', 'AVFoundation', 'MediaPlayer'
end