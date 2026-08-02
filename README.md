# Lens Vocabulary

Lens Vocabulary is an open-source iPhone and iPad experiment for learning from text on another screen.

Point the camera at subtitles, slides, a math video, or a second display. The app reads the selected region locally with Apple's Vision OCR, highlights one useful word, and saves lightweight review cards.

## Why this exists

This project explores a privacy-preserving way to experience on-device AI capabilities without requiring screen-recording permissions from other apps. Instead of reading the device screen, Lens Vocabulary uses the camera as a live "learning lens" pointed at another display.

## Current prototype

- Live camera preview with AVFoundation
- Resizable subtitle/text focus window
- On-device OCR with Vision
- Stable text detection to avoid noisy repeated hints
- Local vocabulary heuristic for useful word selection
- Card capture for words seen in context
- Runtime stats for OCR latency and frame cadence

## Roadmap

- Optional Core ML model for personalized "should I prompt this word?" scoring
- Metal-based text region enhancement for glare, contrast, and moire reduction
- Math mode for terms, symbols, and formula context
- Export review cards
- iCloud sync and spaced repetition

## Requirements

- Xcode 26 or newer
- iOS 18 or newer
- A physical iPhone or iPad with a camera

The simulator can build the app, but a real device is required for the camera flow.

## Build

```bash
xcodegen generate
xcodebuild -project LensVocabulary.xcodeproj -scheme LensVocabulary -destination 'generic/platform=iOS Simulator' build
```

Then open `LensVocabulary.xcodeproj` in Xcode and run on a physical device.

## Privacy

The prototype does not upload frames, text, or saved cards. OCR and vocabulary selection run locally on the device.

## License

MIT
