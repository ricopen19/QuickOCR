# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-02-04

### Added

- **Core Functionality**
  - Global shortcut `Cmd+Shift+O` to trigger screen capture.
  - Rectangular selection UI with drag-and-drop.
  - Fast text recognition (OCR) using Vision Framework.
  - Automatic copying of recognized text to clipboard.
- **Settings & Customization**
  - Configurable global shortcut with conflict detection.
  - "Launch at Login" option.
  - Sound feedback option (success/failure sounds).
  - Text formatting option to remove unnecessary line breaks.
- **UI/UX**
  - Menu bar icon for quick access to settings.
  - Onboarding flow with permission requests and tutorial.
  - Native macOS notifications for OCR results.
- **Documentation**
  - Comprehensive User Guide and Troubleshooting documents.

### Security

- Offline-first architecture (no external data transmission).
- Minimal permission requests (Screen Recording only).
