# GreenShot 🏀

GreenShot is an iOS app that watches a basketball hoop through your iPhone camera, detects when a shot goes up, and plays a sound on every made shot. Point your phone at the court, tap the hoop, hit play, and start shooting.

## How it works

The detection pipeline runs entirely on-device in real time:

1. **Camera capture** — `CameraManager` streams frames from the device camera.
2. **Ball detection** — `BallDetector` runs a YOLOv8n CoreML model (via Vision) on each frame, looking for the COCO `sports ball` class. Detections are returned as normalized center points with a confidence score.
3. **Shot detection** — `ShotDetector` buffers the ball's trajectory (~1.5s at 30fps) and analyzes it for a parabolic arc directed toward the hoop. It distinguishes shots from passes using upward rise, apex/descent, minimum arc height, and proximity to the hoop.
4. **Audio feedback** — `SoundManager` plays a sound whenever a shot is detected.

A live overlay draws the tracked ball, its trajectory, and the hoop location for visual feedback, and a counter tracks total shots.

## Features

- Real-time, on-device basketball detection (Neural Engine + GPU + CPU via CoreML).
- Tap-to-set hoop location for direction-aware shot detection.
- Shot vs. pass discrimination based on trajectory arc analysis.
- Configurable sound playback modes: **Single**, **Cycle**, and **Random**.
- Live trajectory/ball overlay and shot counter.
- Cooldown between triggers to prevent double-firing.

## Requirements

- iOS 17.0+ (iPhone)
- Xcode 15.0+
- Swift 5.9
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (the project is defined in `project.yml`)

## Getting started

The Xcode project is generated from `project.yml` using XcodeGen.

```bash
# Install XcodeGen if you don't have it
brew install xcodegen

# Generate the Xcode project
xcodegen generate

# Open the project
open GreenShot.xcodeproj
```

Then select your development team in the target's signing settings and run on a physical device (the camera is not available in the Simulator).

## Project structure

```
GreenShot/
├── GreenShotApp.swift        # App entry point
├── Camera/
│   └── CameraManager.swift   # Camera capture session + frame delivery
├── Detection/
│   ├── BallDetector.swift    # YOLOv8n + Vision ball detection
│   └── ShotDetector.swift    # Trajectory analysis / shot logic
├── Audio/
│   └── SoundManager.swift    # Sound playback and modes
├── Models/
│   ├── SoundMode.swift       # Single / Cycle / Random
│   └── TrajectoryPoint.swift # A tracked ball position
├── Views/
│   ├── ContentView.swift     # Main UI + pipeline wiring
│   ├── CameraPreviewView.swift
│   ├── OverlayView.swift     # Ball/trajectory/hoop overlay
│   └── SoundPickerView.swift # Sound configuration UI
└── Resources/
    └── yolov8n.mlpackage     # CoreML detection model
```

## Usage

1. Launch the app and allow camera access.
2. Position the phone so the hoop is in view.
3. Tap the hoop location on screen to arm the detector.
4. Tap the **play** button to start detection.
5. Take shots — a sound plays and the counter increments on each detected shot.
6. Use the **music** button to change sounds, and the **scope** button to reset the hoop.

## Notes

- Detection accuracy depends on lighting, camera angle, and how clearly the ball is visible.
- The bundled `yolov8n.pt` is the source model; the app ships the compiled `yolov8n.mlpackage`.
