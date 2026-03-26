# SavedMessages

iOS + iPad App for SavedMessages — Version 1.1

## Features (Version 1.1)

### Inhalte speichern
- **Text & URLs**: Freitext oder URLs hinzufügen — URLs werden automatisch erkannt und mit dem Tag „URL" versehen
- **Fotos & Videos**: Aus der Fotobibliothek auswählen oder direkt mit der Kamera aufnehmen (bis zu 10 gleichzeitig)
- **Audio-Aufnahmen**: Sprachmemos direkt in der App aufnehmen mit Echtzeit-Timer-Anzeige
- **Dateien**: Beliebige Dateien über die Share Extension empfangen (PDF, Dokumente etc.)

### Organisieren
- **Tags**: Automatische Tags (Text, URL, Foto, Video, Audio, Datei) und benutzerdefinierte Tags
- **Quick-Tag-Verwaltung**: Tags direkt über das Kontextmenü oder Swipe-Geste verwalten
- **Tag-Übersicht**: Alle Tags mit Anzahl in der Tags-Ansicht, Tap zum Filtern
- **Umbenennen**: Benutzerdefinierte Namen für jeden Eintrag vergeben
- **Mehrfachauswahl**: Einträge im Auswahlmodus selektieren und in Bulk löschen

### Standort (Neu in 1.1)
- **Automatische Standorterfassung**: Beim Speichern von Einträgen wird der aktuelle Standort automatisch erfasst (sofern Berechtigung erteilt)
- **Geocodierte Adresse**: Der Standort wird als lesbare Adresse (Stadt, Land) angezeigt
- **Anzeige in der Liste**: Einträge mit Standort zeigen ein Kartennadel-Symbol mit der Adresse in der Item-Liste

### Teilen
- **Share Sheet**: Einträge über den Detail-Ansicht-Share-Button oder das Kontextmenü teilen
- **Share Extension**: Inhalte aus jeder App direkt in SavedMessages speichern
  - Erkennung der Quell-App (Safari, Mail, Chrome, Instagram, Twitter u.v.m.)
  - Tag-Auswahl beim Speichern über die Share Extension
  - Automatische Standorterfassung auch in der Share Extension

### Synchronisation
- **iCloud-Sync**: Automatische One-Way-Synchronisation (lokal → iCloud)
- **Cross-Process-Kommunikation**: Echtzeit-Benachrichtigung zwischen Share Extension und Haupt-App via Darwin Notifications

### Benutzeroberfläche
- **Tab-Navigation**: Items, Settings, Tags
- **Detail-Ansicht**: Vollständige Anzeige aller Inhaltstypen mit Done-, Edit- und Share-Buttons
- **Kontextmenü**: Teilen, Tags verwalten, Löschen per Long-Press
- **Swipe-Aktionen**: Rechts-Swipe für Tags, Links-Swipe zum Löschen
- **Leerer Zustand**: Informative Anzeige wenn keine Einträge vorhanden
- **Settings**: App-Version und Build-Nummer anzeigen

## Daten-Architektur

### Übersicht

SavedMessages speichert alle Daten **dateibasiert** (JSON + Dateisystem). Es wird kein CoreData, SwiftData oder SQLite verwendet. Sowohl die Haupt-App als auch die Share Extension greifen auf denselben gemeinsamen App-Group-Container zu.

### Wo werden die Daten gespeichert?

```
App Group Container (group.com.HerrTete.SavedMessages)
├── items.json                    ← JSON-Array aller DataItem-Einträge (Metadaten)
└── Files/
    ├── {uuid}.jpg                ← Bilder
    ├── {uuid}.png
    ├── {uuid}.mp4                ← Videos
    ├── {uuid}.m4a                ← Audio-Aufnahmen
    └── ...                       ← Weitere Dateien (PDF, etc.)

iCloud Container (iCloud.com.HerrTete.SavedMessages)
└── Documents/
    ├── items.json                ← Kopie der lokalen items.json (One-Way-Sync)
    └── Files/                    ← Kopie der lokalen Dateien
        └── ...
```

### Datenmodell (`DataItem`)

Jeder gespeicherte Eintrag wird als `DataItem`-Struct in der Datei `items.json` abgelegt:

| Eigenschaft   | Typ              | Beschreibung                                                |
|---------------|------------------|-------------------------------------------------------------|
| `id`          | `String`         | Eindeutige UUID des Eintrags                                |
| `type`        | `DataItemType`   | Art des Inhalts: `text`, `image`, `video`, `audio`, `file`  |
| `title`       | `String`         | Anzeige-Titel (z. B. Dateiname oder Text-Vorschau)          |
| `customName`  | `String?`        | Optionaler benutzerdefinierter Name                         |
| `tags`        | `[String]`       | Liste der zugewiesenen Tags (z. B. `["Foto", "Urlaub"]`)    |
| `textContent` | `String?`        | Textinhalt oder URL (nur bei Typ `text`)                    |
| `fileName`    | `String?`        | Dateiname im `Files/`-Ordner (UUID + Erweiterung)           |
| `mimeType`    | `String?`        | MIME-Typ der Datei (z. B. `image/jpeg`)                     |
| `createdAt`   | `TimeInterval`   | Erstellungszeitpunkt (Sekunden seit 1970)                   |
| `sourceApp`   | `String?`        | Quell-App (bei Inhalten über die Share Extension, optional, kann `nil` sein) |
| `location`    | `String?`        | Geocodierter Standort beim Speichern (z. B. „Berlin, Deutschland") |

### Tags

Tags werden als **String-Array** direkt in jedem `DataItem` gespeichert – es gibt keine separate Tag-Tabelle oder -Datei.

**Automatische Tags** beim Erstellen:

| Inhaltstyp | Standard-Tag |
|------------|-------------|
| Text       | `Text`      |
| URL        | `URL`       |
| Bild       | `Foto`      |
| Video      | `Video`     |
| Audio      | `Audio`     |
| Datei      | `Datei`     |

**Tag-Operationen:**
- Hinzufügen/Entfernen von Tags über die Bearbeitungsansicht oder den Quick-Tag-Dialog
- Vorschläge basierend auf bereits vorhandenen Tags (Präfix-Suche)
- Filtern der Item-Liste nach einem bestimmten Tag
- Alle eindeutigen Tags werden aus den Items aggregiert (`allTags`)

### Datei-Speicherung

Binäre Inhalte (Bilder, Videos, Audio, Dateien) werden **nicht** in der `items.json` gespeichert, sondern als separate Dateien im `Files/`-Ordner. Der `DataItem` verweist über die Eigenschaft `fileName` auf die jeweilige Datei.

Dateiname-Schema: `{UUID}.{Erweiterung}` (z. B. `A1B2C3D4-E5F6-7890-ABCD-EF1234567890.jpg`)

### iCloud-Synchronisation

Die App führt eine **One-Way-Synchronisation** (lokal → iCloud) durch:
- Nach jedem Speichervorgang wird `items.json` in den iCloud-Documents-Container kopiert
- Neue Dateien im `Files/`-Ordner werden ebenfalls in den iCloud-Container kopiert
- Dateien werden dabei **nur hochgeladen, wenn sie im iCloud-Ziel noch nicht existieren** (keine Aktualisierung/Überschreibung bestehender Dateien)
- In iCloud bereits vorhandene Dateien werden **nicht automatisch gelöscht**, auch wenn sie lokal entfernt wurden (kein vollständiges Spiegeln des lokalen Zustands)
- Es gibt **keine Konflikterkennung** und keinen Rück-Sync von iCloud zum lokalen Speicher

### Share Extension

Die Share Extension nutzt denselben App-Group-Container (`group.com.HerrTete.SavedMessagesGroup`) und das gleiche `DataItem`-Modell. Gemeinsamer Code befindet sich im `Shared/`-Ordner:

- `Shared/DataItem.swift` — Datenmodell
- `Shared/StorageConstants.swift` — App-Group-ID, iCloud-Container-ID, Datei-/Ordnernamen und URL-Helfer
- `Shared/ItemTypeHelpers.swift` — Typbestimmung (MIME-Type, Dateiendung), Standard-Tags, URL-Erkennung
- `Shared/LocationService.swift` — Standortdienst (CLLocationManager + CLGeocoder, Singleton)

## Projekt-Struktur

```
Shared/                             ← Gemeinsamer Code (App + Extension)
├── DataItem.swift                  ← Datenmodell
├── StorageConstants.swift          ← Zentrale Konstanten & Pfade
├── LocationService.swift           ← Standortdienst (CLLocationManager + Geocoding)
└── ItemTypeHelpers.swift           ← Typ-Erkennung & Standard-Tags
SavedMessages/                      ← Haupt-App
├── SavedMessagesApp.swift          ← App-Einstiegspunkt
├── ContentView.swift               ← Tab-Ansicht (Items, Settings, Tags)
├── Services/
│   └── StorageService.swift        ← Persistence-Layer (laden, speichern, iCloud-Sync)
└── Views/
    ├── ItemListView.swift          ← Item-Liste mit Filter, Thumbnails & Mehrfachauswahl
    ├── ItemDetailView.swift        ← Detail-, Bearbeitungs-, Quick-Tag- & Share-Ansichten
    ├── SettingsView.swift          ← App-Version & Build-Nummer
    ├── TagsView.swift              ← Tag-Übersicht mit Zählern
    ├── AddTextView.swift           ← Text/URL hinzufügen (mit Standorterfassung)
    ├── AddAudioView.swift          ← Audio aufnehmen (mit Standorterfassung)
    ├── AddPhotoVideoView.swift     ← Foto/Video hinzufügen (mit Standorterfassung)
    └── CameraPickerView.swift      ← Kamera-Auswahl (UIImagePickerController)
ShareExtension/                     ← Share Extension
├── ShareViewController.swift       ← Verarbeitung geteilter Inhalte
└── ShareTagPickerView.swift        ← Tag-Auswahl in der Share Extension
SavedMessagesUITests/               ← UI-Tests
└── SavedMessagesUITests.swift      ← Umfassende UI-Tests für alle Features
README.md
```
