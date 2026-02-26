import Foundation
import UIKit
@preconcurrency import Vision

public enum SpeciesClassifierError: Error {
    case invalidImage
}

public struct SpeciesClassification: Hashable {
    public let identifier: String
    public let normalizedLabel: String
    public let confidence: Double

    public init(identifier: String, normalizedLabel: String, confidence: Double) {
        self.identifier = identifier
        self.normalizedLabel = normalizedLabel
        self.confidence = confidence
    }
}

public final class SpeciesClassifier {
    public init() {}

    public func classify(
        image: UIImage,
        maxResults: Int = 5
    ) async throws -> [SpeciesClassification] {
        guard let cgImage = image.cgImage else {
            throw SpeciesClassifierError.invalidImage
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNClassifyImageRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let observations = (request.results as? [VNClassificationObservation]) ?? []
                let predictions = observations.prefix(maxResults).map { observation in
                    SpeciesClassification(
                        identifier: observation.identifier,
                        normalizedLabel: Self.normalize(label: observation.identifier),
                        confidence: Double(observation.confidence)
                    )
                }
                continuation.resume(returning: predictions)
            }
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    public static func normalize(label: String) -> String {
        label
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: ",", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}
