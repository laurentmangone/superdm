# SuperDM

Download manager for macOS with CLI and GUI interfaces.

## Features

### GUI (Graphical Interface)
- Modern macOS Tahoe-style interface
- Download list with status filters
- Bulk actions (multi-selection)
- Controls: Add, Start, Pause, Cancel, Retry, Delete
- Preferences: max parallel downloads, destination folder

### CLI (Command Line)
- Add downloads by URL
- Import from file (one URL per line)
- List downloads with filters
- Download control

## Installation

### Requirements
- macOS 13.0+
- Swift 5.9+

### Build
```bash
swift build -c release
```

### DMG
Download `superdm.dmg` and drag the app to `/Applications`.

## Usage

### GUI

Launch the app:
```bash
swift run GUI
```

Or open `superdm-gui.app` from `/Applications`.

#### Keyboard Shortcuts
- `Cmd+N` : New download
- `Cmd+,` : Preferences
- `Cmd+Click` : Multi-select
- `Shift+Click` : Range select
- `Delete` : Delete

#### Toolbar
| Button | Action |
|--------|--------|
| ⚙️ | Preferences |
| ➕ | Add a download |
| ▶️ | Start/Resume |
| 🔄 | Retry (failed) |
| ⏸️ | Pause |
| ✖️ | Cancel |
| 🗑️ | Delete |

### CLI

Launch the CLI:
```bash
swift run CLI <command>
```

#### Commands

**Add a download:**
```bash
superdm add <url> [--to <folder>]
```

**List downloads:**
```bash
superdm list [--status <all|downloading|paused|completed|failed|pending>]
```

**Control a download:**
```bash
superdm pause <id>
superdm resume <id>
superdm cancel <id>
superdm remove <id>
```

**Preferences:**
```bash
superdm preferences                    # Show preferences
superdm preferences --max-parallel 5  # Set max parallel downloads
superdm preferences --folder ~/Downloads  # Set download folder
```

#### Examples

```bash
# Add a download
swift run CLI add https://example.com/file.zip

# Add with custom folder
swift run CLI add https://example.com/file.zip --to ~/Downloads

# List ongoing downloads
swift run CLI list --status downloading

# Pause
swift run CLI pause 550e8400-e29b-41d4-a716-446655440000

# Retry a failed download
swift run CLI resume 550e8400-e29b-41d4-a716-446655440000

# Set 5 parallel downloads
swift run CLI preferences --max-parallel 5
```

## Architecture

```
superdm/
├── Sources/
│   ├── App/           # Shared code (DownloadManager, Database, Preferences)
│   ├── CLI/           # Command line interface
│   └── GUI/           # SwiftUI graphical interface
├── Package.swift      # Swift package configuration
└── superdm.dmg        # Installer
```

### Main Components

- **DownloadManager**: Manages downloads with URLSession
- **Database**: Persistent storage with SQLite
- **Preferences**: User settings with UserDefaults

## License

MIT
