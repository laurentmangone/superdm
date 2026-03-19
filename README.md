# SuperDM

Gestionnaire de téléchargements pour macOS avec interface CLI et GUI.

## Fonctionnalités

### GUI (Interface graphique)
- Interface moderne style macOS Tahoe
- Liste des téléchargements avec filtres par statut
- Actions en masse (multi-sélection)
- Contrôles: Ajouter, Démarrer, Pauser, Annuler, Réessayer, Supprimer
- Préférences: nombre max de téléchargements parallèles, dossier de destination

### CLI (Ligne de commande)
- Ajout de téléchargements par URL
- Import depuis fichier (une URL par ligne)
- Liste des téléchargements avec filtres
- Contrôle des téléchargements

## Installation

### Prérequis
- macOS 13.0+
- Swift 5.9+

### Build
```bash
swift build -c release
```

### DMG
Téléchargez `superdm.dmg` et glissez l'application dans `/Applications`.

## Utilisation

### GUI

Lancez l'application:
```bash
swift run GUI
```

Ou ouvrez `superdm-gui.app` depuis `/Applications`.

#### Raccourcis clavier
- `Cmd+N` : Nouveau téléchargement
- `Cmd+,` : Préférences
- `Cmd+Click` : Sélection multiple
- `Shift+Click` : Sélection par plage
- `Delete` : Supprimer

#### Barre d'outils
| Bouton | Action |
|--------|--------|
| ⚙️ | Préférences |
| ➕ | Ajouter un téléchargement |
| ▶️ | Démarrer/Reprendre |
| 🔄 | Réessayer (échoué) |
| ⏸️ | Pauser |
| ✖️ | Annuler |
| 🗑️ | Supprimer |

### CLI

Lancez le CLI:
```bash
swift run CLI <commande>
```

#### Commandes

**Ajouter un téléchargement:**
```bash
superdm add <url> [--to <dossier>]
```

**Lister les téléchargements:**
```bash
superdm list [--status <all|downloading|paused|completed|failed|pending>]
```

**Contrôler un téléchargement:**
```bash
superdm pause <id>
superdm resume <id>
superdm cancel <id>
superdm remove <id>
```

**Préférences:**
```bash
superdm preferences                    # Afficher les préférences
superdm preferences --max-parallel 5  # Définir le nombre max de téléchargements parallèles
superdm preferences --folder ~/Downloads  # Définir le dossier de téléchargement
```

#### Exemples

```bash
# Ajouter un téléchargement
swift run CLI add https://example.com/file.zip

# Ajouter avec dossier personnalisé
swift run CLI add https://example.com/file.zip --to ~/Downloads

# Lister les téléchargements en cours
swift run CLI list --status downloading

# Mettre en pause
swift run CLI pause 550e8400-e29b-41d4-a716-446655440000

# Réessayer un téléchargement échoué
swift run CLI resume 550e8400-e29b-41d4-a716-446655440000

# Définir 5 téléchargements parallèles
swift run CLI preferences --max-parallel 5
```

## Architecture

```
superdm/
├── Sources/
│   ├── App/           # Code partagé (DownloadManager, Database, Preferences)
│   ├── CLI/           # Interface en ligne de commande
│   └── GUI/           # Interface graphique SwiftUI
├── Package.swift      # Configuration du package Swift
└── superdm.dmg        # Installateur
```

### Composants principaux

- **DownloadManager**: Gère les téléchargements avec URLSession
- **Database**: Stockage persistant avec SQLite
- **Preferences**: Configuration utilisateur avec UserDefaults

## Licence

MIT
