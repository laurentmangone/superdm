# AGENTS.md

## Project Overview

**superdm** (Super Download Manager) is a macOS download manager with CLI and GUI interfaces featuring modern macOS Tahoe design.

## App Specifications

- **Name**: superdm
- **UI**: CLI and GUI (AppKit/SwiftUI)
- **Design**: Modern macOS Tahoe design language

## Features

- Add single URL or file import (single URL per line)
- Select destination download folder
- Download list with status filters (all, downloading, paused, completed, failed)
- Download controls: pause, resume, cancel, delete
- Display: filename, destination folder, speed, size, completion percentage
- Preferences: maximum number of parallel downloads
- Toolbar with action buttons for downloads

## Build Commands

- Build: `swift build`
- Run CLI: `swift run CLI <command>`
- Run GUI: `swift run GUI`

## Code Style

- Swift with Swift Package Manager
- Use native macOS frameworks (AppKit or SwiftUI)
- Follow Swift API Design Guidelines
- Use modern Swift concurrency (async/await)

## Architecture

- Shared download engine between CLI and GUI
- SQLite for persistent download history
- URLSession for downloads with progress tracking

## CLI Commands

- `superdm add <url> [--to <destination>]` - Add a download
- `superdm list [--status <all|downloading|paused|completed|failed>]` - List downloads
- `superdm pause <id>` - Pause a download
- `superdm resume <id>` - Resume a download
- `superdm cancel <id>` - Cancel a download
- `superdm remove <id>` - Remove a download
- `superdm preferences` - Show/set preferences

## GUI Layout

- **Toolbar**: Add, Pause, Resume, Cancel, Delete buttons
- **Sidebar**: Filter by status (All, Downloading, Paused, Completed, Failed)
- **Main Content**: Download list with columns (Name, Destination, Speed, Size, Progress)
- **Preferences Window**: Max parallel downloads setting

## Dependencies

- swift-argument-parser (CLI argument parsing)
- SQLite.swift (persistent storage)
