# 9. AI Species Identification

**Priority**: Tier 3 — Blue Ocean differentiator
**Estimated Complexity**: High
**Modules**: `FeatureMap` (UI), new CoreML model, `UmiDB`
**Dependencies**: Sighting Photos (#7) must be implemented first

---

## Problem

Divers photograph marine life but often can't identify what they saw. AI-powered species identification from photos would differentiate UmiLog and enrich the species tracking data.

## Current State

- Comprehensive species catalog: `WildlifeSpecies` with WoRMS, GBIF, FishBase IDs
- 5 categories: fish, coral, mammal, invertebrate, reptile
- Species-site links with likelihood data
- No photo capture (prerequisite: plan #7)
- No CoreML models bundled
- No Vision framework usage

## Implementation Plan — Phased

### Phase 1: Camera Integration (ships with #7)

Covered in plan #7. Prerequisite: users can take/attach photos to sightings.

### Phase 2: On-Device Vision Classifier

#### Step 1: Source or Train a CoreML Model

**Option A — Use existing model** (recommended to start):
- Apple's built-in `VNClassifyImageRequest` classifies 1000+ categories but is generic (not marine-specific)
- iNaturalist's model (open source) covers marine species but is large (~100MB)

**Option B — Train a custom model**:
- Source: iNaturalist observation photos (CC-licensed, API available)
- Filter to marine species in UmiLog's catalog
- Use Create ML (Apple's tool) for transfer learning
- Target: Top 200 most common marine species divers encounter

Model spec:
```
Input: 299x299 RGB image
Output: Top-5 species predictions with confidence scores
Size target: < 30MB (on-device)
Classes: 200-500 marine species
Min accuracy: 80% top-3 for common species
```

#### Step 2: Prediction Service

```swift
// UmiCoreKit/AI/SpeciesClassifier.swift
import Vision
import CoreML

final class SpeciesClassifier {
    private let model: VNCoreMLModel

    init() throws {
        let config = MLModelConfiguration()
        config.computeUnits = .cpuAndNeuralEngine  // Use Neural Engine when available
        let mlModel = try MarineSpeciesClassifier(configuration: config).model
        self.model = try VNCoreMLModel(for: mlModel)
    }

    struct Prediction {
        let speciesId: String?       // matched to WildlifeSpecies.id if possible
        let scientificName: String
        let commonName: String
        let confidence: Float        // 0.0–1.0
        let category: WildlifeSpecies.Category?
    }

    func classify(image: UIImage) async throws -> [Prediction] {
        guard let cgImage = image.cgImage else { throw ClassifierError.invalidImage }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNCoreMLRequest(model: model) { request, error in
                if let error { continuation.resume(throwing: error); return }

                let results = (request.results as? [VNClassificationObservation]) ?? []
                let predictions = results.prefix(5).map { obs in
                    self.mapToPrediction(observation: obs)
                }
                continuation.resume(returning: predictions)
            }
            request.imageCropAndScaleOption = .centerCrop

            let handler = VNImageRequestHandler(cgImage: cgImage)
            try? handler.perform([request])
        }
    }

    /// Map model output label to our WildlifeSpecies catalog
    private func mapToPrediction(observation: VNClassificationObservation) -> Prediction {
        let label = observation.identifier  // e.g., "Manta_birostris"
        let scientificName = label.replacingOccurrences(of: "_", with: " ")

        // Try to find matching species in our DB
        let species = try? AppDatabase.shared.reader.read { db in
            try WildlifeSpecies
                .filter(Column("scientificName").collating(.nocase) == scientificName)
                .fetchOne(db)
        }

        return Prediction(
            speciesId: species?.id,
            scientificName: scientificName,
            commonName: species?.name ?? scientificName,
            confidence: observation.confidence,
            category: species?.category
        )
    }
}
```

#### Step 3: Identification UI

After taking a photo in the sighting flow:

```
┌─ Species Identification ────────┐
│                                 │
│ ┌─────────────────────────────┐ │
│ │                             │ │
│ │       [Photo Preview]       │ │
│ │                             │ │
│ └─────────────────────────────┘ │
│                                 │
│ 🤖 AI Suggestions:             │
│                                 │
│ ┌─ 94% ─────────────────────┐  │
│ │ Manta birostris            │  │
│ │ Giant Oceanic Manta Ray    │  │
│ │ [Select]                   │  │
│ └────────────────────────────┘  │
│ ┌─ 73% ─────────────────────┐  │
│ │ Mobula alfredi             │  │
│ │ Reef Manta Ray             │  │
│ │ [Select]                   │  │
│ └────────────────────────────┘  │
│ ┌─ 12% ─────────────────────┐  │
│ │ Mobula mobular             │  │
│ │ Giant Devil Ray             │  │
│ │ [Select]                   │  │
│ └────────────────────────────┘  │
│                                 │
│ Not what you saw?               │
│ [Search Species Manually]       │
└─────────────────────────────────┘
```

Flow:
1. User takes/selects photo → auto-classify
2. Show top 3-5 suggestions with confidence bars
3. User taps to select species → pre-fills sighting form
4. "Not listed" → fall back to manual species search (existing)
5. Save selection + confidence as metadata on sighting

#### Step 4: Site-Contextual Filtering

Improve accuracy by filtering predictions against species known at the current site:

```swift
func classifyWithContext(image: UIImage, siteId: String) async throws -> [Prediction] {
    let allPredictions = try await classify(image: image)

    // Boost predictions for species known at this site
    let siteSpecies = try await fetchSiteSpecies(siteId: siteId)
    let siteSpeciesIds = Set(siteSpecies.map(\.speciesId))

    return allPredictions.map { prediction in
        var adjusted = prediction
        if let id = prediction.speciesId, siteSpeciesIds.contains(id) {
            // Boost confidence for site-appropriate species
            adjusted.confidence = min(1.0, prediction.confidence * 1.2)
        }
        return adjusted
    }.sorted { $0.confidence > $1.confidence }
}
```

### Phase 3: Server-Side Model (Future)

- Upload anonymized photos for better model training
- Server model with larger capacity (MobileNet → EfficientNet-B4)
- Federated learning from user confirmations
- Cover 2000+ species vs 200-500 on-device

## Model Training Pipeline (If Custom)

```
1. Data collection:
   - iNaturalist API: observations with "marine" habitat
   - Filter to species in UmiLog catalog
   - Min 50 photos per species, target 200+
   - Augmentation: rotation, flip, color jitter, underwater color cast

2. Training:
   - Create ML (simplest) or PyTorch + coremltools
   - Base: MobileNetV3 (fast, small) or EfficientNet-B0
   - Transfer learning: freeze base, train classifier head
   - Validation: 80/10/10 split

3. Export:
   - CoreML .mlmodel format
   - Quantize to INT8 for smaller size
   - Target: <30MB model file

4. Bundle:
   - Ship with app initially
   - Later: download on demand via BackgroundAssets framework
```

## Testing

- [ ] Classify a clear fish photo → correct top-1 prediction
- [ ] Classify an ambiguous photo → reasonable top-3 spread
- [ ] Classify a non-marine photo → low confidence across all
- [ ] Select a suggestion → species pre-fills in sighting form
- [ ] "Search manually" fallback works
- [ ] Site-context boosting improves relevant species ranking
- [ ] Model inference time < 500ms on iPhone 12+
- [ ] Model size < 30MB in app bundle
- [ ] Test on Neural Engine vs CPU-only devices

## Risks

- **Model accuracy**: Marine species ID is hard (underwater photos have color distortion, motion blur, partial views). Set user expectations with confidence scores
- **Model size**: Large models impact app download size. Consider on-demand download
- **Training data**: iNaturalist photos are above-water or snorkeling quality, not representative of deep dive photos. May need dive-specific training data
- **Liability**: Never present AI ID as definitive. Always show confidence and manual override. Important for venomous species identification
