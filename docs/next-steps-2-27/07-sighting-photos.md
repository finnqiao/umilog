# 7. Photo Attachments for Sightings

**Priority**: Tier 2 — Prerequisite for AI Species ID
**Estimated Complexity**: Medium
**Modules**: `UmiDB` (migration), `FeatureMap` (sighting UI), `UmiCloudKit` (asset sync)
**Migration**: v10 (batch with other v10 changes)

---

## Problem

Wildlife sightings currently have no photo support. Photos are the prerequisite for future AI species identification and make sighting records far more valuable for both the user and the community.

## Current State

- `WildlifeSighting` stores: id, diveId, speciesId, count, notes, createdAt
- Sighting form is part of the dive log wizard
- Species have `imageUrl` and `thumbnailUrl` fields (catalog images, not user photos)
- `SiteMedia` model exists for licensed site photos — similar pattern can be reused
- No user photo capture anywhere in the app

## Implementation Plan

### Step 1: SightingPhoto Model + Migration

```swift
// UmiDB/Models/SightingPhoto.swift
struct SightingPhoto: Codable, FetchableRecord, PersistableRecord, Identifiable {
    static let databaseTableName = "sighting_photos"

    var id: String              // UUID
    var sightingId: String      // FK → sightings
    var filename: String        // relative path in documents dir
    var thumbnailFilename: String  // smaller version for lists
    var width: Int
    var height: Int
    var capturedAt: Date?       // EXIF date if available
    var latitude: Double?       // EXIF GPS if available
    var longitude: Double?
    var sortOrder: Int          // for manual reordering
    var createdAt: Date

    // Association
    static let sighting = belongsTo(WildlifeSighting.self)
}

// Extend WildlifeSighting
extension WildlifeSighting {
    static let photos = hasMany(SightingPhoto.self)
    var photos: QueryInterfaceRequest<SightingPhoto> {
        request(for: Self.photos).order(Column("sortOrder"))
    }
}
```

Migration:
```swift
try db.create(table: "sighting_photos") { t in
    t.primaryKey("id", .text).notNull()
    t.column("sightingId", .text).notNull()
        .references("sightings", onDelete: .cascade)
    t.column("filename", .text).notNull()
    t.column("thumbnailFilename", .text).notNull()
    t.column("width", .integer).notNull()
    t.column("height", .integer).notNull()
    t.column("capturedAt", .datetime)
    t.column("latitude", .double)
    t.column("longitude", .double)
    t.column("sortOrder", .integer).notNull().defaults(to: 0)
    t.column("createdAt", .datetime).notNull()
}
```

### Step 2: Photo Storage Service

```swift
// UmiCoreKit/PhotoStorageService.swift
final class PhotoStorageService {
    private let baseDir: URL  // documents/sighting_photos/

    /// Save a photo, generate thumbnail, return filenames
    func save(image: UIImage, for sightingId: String) throws -> (filename: String, thumbnail: String) {
        let id = UUID().uuidString
        let filename = "\(sightingId)/\(id).jpg"
        let thumbFilename = "\(sightingId)/\(id)_thumb.jpg"

        // Full size: max 2048px on longest edge, JPEG 0.85
        let fullImage = image.resized(maxDimension: 2048)
        let fullData = fullImage.jpegData(compressionQuality: 0.85)!
        try write(fullData, to: filename)

        // Thumbnail: 300px, JPEG 0.7
        let thumbImage = image.resized(maxDimension: 300)
        let thumbData = thumbImage.jpegData(compressionQuality: 0.7)!
        try write(thumbData, to: thumbFilename)

        return (filename, thumbFilename)
    }

    /// Delete all photos for a sighting
    func deletePhotos(for sightingId: String) throws {
        let dir = baseDir.appendingPathComponent(sightingId)
        try FileManager.default.removeItem(at: dir)
    }

    /// Get full URL for a photo filename
    func url(for filename: String) -> URL {
        baseDir.appendingPathComponent(filename)
    }
}
```

### Step 3: Photo Capture/Picker in Sighting Form

Add photo support to the existing sighting entry flow:

```
┌─ Log Sighting ──────────────────┐
│                                 │
│ Species  [Manta Ray       ▾]   │
│ Count    [- 1 +]               │
│                                 │
│ Photos                          │
│ ┌─────┐ ┌─────┐ ┌─────┐       │
│ │ 📷  │ │ img │ │ img │       │
│ │ Add │ │  1  │ │  2  │       │
│ └─────┘ └─────┘ └─────┘       │
│                                 │
│ Notes  [________________________]│
│                                 │
│        [Save Sighting]          │
└─────────────────────────────────┘
```

```swift
// FeatureMap/Wildlife/SightingPhotoSection.swift
struct SightingPhotoSection: View {
    @State private var photos: [UIImage] = []
    @State private var showingPicker = false
    @State private var showingCamera = false

    var body: some View {
        VStack(alignment: .leading) {
            Text("Photos")
                .font(.subheadline.weight(.medium))

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 8) {
                    // Add button
                    Menu {
                        Button("Take Photo", systemImage: "camera") {
                            showingCamera = true
                        }
                        Button("Choose from Library", systemImage: "photo.on.rectangle") {
                            showingPicker = true
                        }
                    } label: {
                        AddPhotoPlaceholder()
                    }

                    // Existing photos
                    ForEach(photos.indices, id: \.self) { i in
                        SightingPhotoThumbnail(image: photos[i])
                            .contextMenu {
                                Button("Remove", role: .destructive) {
                                    photos.remove(at: i)
                                }
                            }
                    }
                }
            }
        }
        .photosPicker(isPresented: $showingPicker, selection: ..., maxSelectionCount: 10)
        .fullScreenCover(isPresented: $showingCamera) {
            CameraView(onCapture: { image in photos.append(image) })
        }
    }
}
```

### Step 4: Photo Gallery on Sighting Detail

When viewing a sighting's details:

```swift
// FeatureMap/Wildlife/SightingPhotoGallery.swift
struct SightingPhotoGallery: View {
    let photos: [SightingPhoto]
    @State private var selectedIndex: Int?

    var body: some View {
        // Grid of thumbnails
        LazyVGrid(columns: [.init(.adaptive(minimum: 80))], spacing: 4) {
            ForEach(photos) { photo in
                AsyncImage(url: photoStorage.url(for: photo.thumbnailFilename))
                    .aspectRatio(1, contentMode: .fill)
                    .onTapGesture {
                        selectedIndex = photos.firstIndex(of: photo)
                    }
            }
        }
        .fullScreenCover(item: $selectedIndex) { index in
            // Full-screen paging gallery
            PhotoPageView(photos: photos, initialIndex: index)
        }
    }
}
```

### Step 5: CloudKit Asset Sync

Extend sync to handle photo assets:

```swift
extension SightingPhoto: SyncableRecord {
    static var ckRecordType: String { "SightingPhoto" }

    func toCKRecord(zoneID: CKRecordZone.ID, encryptor: FieldEncryptor?) -> CKRecord {
        let record = CKRecord(recordType: Self.ckRecordType, recordID: ...)
        record["sightingId"] = sightingId
        record["sortOrder"] = sortOrder

        // Attach photo as CKAsset
        let photoURL = PhotoStorageService.shared.url(for: filename)
        record["photo"] = CKAsset(fileURL: photoURL)

        return record
    }
}
```

- Photos sync as `CKAsset` (CloudKit handles binary data)
- Only sync full-size photos; regenerate thumbnails on the receiving device
- Respect CloudKit's 50MB asset limit (our 2048px JPEGs are ~500KB-2MB)

### Step 6: EXIF Extraction

When a photo is imported from the library, extract EXIF metadata:

```swift
func extractEXIF(from asset: PHAsset) -> (date: Date?, location: CLLocationCoordinate2D?) {
    let date = asset.creationDate
    let location = asset.location?.coordinate
    return (date, location)
}
```

This enables:
- Auto-dating sightings from photo timestamps
- Verifying sighting location against photo GPS

## Testing

- [ ] Add photo from camera to a sighting
- [ ] Add photo from library to a sighting
- [ ] Verify thumbnail generation (correct size, quality)
- [ ] Add multiple photos (up to 10), verify scroll
- [ ] Remove a photo from sighting
- [ ] View photo gallery full-screen with paging
- [ ] Delete a sighting, verify photos cleaned up (cascade)
- [ ] Verify storage directory structure
- [ ] Test with very large photos (4K, 48MP)

## Risks

- **Storage growth**: User photos can grow unbounded. Show storage used in settings, offer cleanup
- **CloudKit bandwidth**: Photos are the heaviest sync payload. Sync over Wi-Fi only by default
- **Privacy**: EXIF GPS data may reveal user's location. Strip EXIF before any community sharing (future)
