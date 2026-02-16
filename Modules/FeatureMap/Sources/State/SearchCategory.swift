import SwiftUI
import UmiDB
import UmiDesignSystem

/// Browseable search categories for the empty-state discovery UI.
enum SearchCategory: String, CaseIterable, Identifiable {
    case wrecks
    case reefs
    case caves
    case walls
    case shore
    case drift
    case beginner
    case advanced
    case nightDiving
    case highBiodiversity

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .wrecks: return "Wrecks"
        case .reefs: return "Reefs"
        case .caves: return "Caves"
        case .walls: return "Walls"
        case .shore: return "Shore"
        case .drift: return "Drift"
        case .beginner: return "Beginner"
        case .advanced: return "Advanced"
        case .nightDiving: return "Night"
        case .highBiodiversity: return "Biodiversity"
        }
    }

    var icon: String {
        switch self {
        case .wrecks: return "ferry.fill"
        case .reefs: return "water.waves"
        case .caves: return "mountain.2.fill"
        case .walls: return "square.stack.3d.up.fill"
        case .shore: return "beach.umbrella.fill"
        case .drift: return "wind"
        case .beginner: return "tortoise.fill"
        case .advanced: return "bolt.fill"
        case .nightDiving: return "moon.stars.fill"
        case .highBiodiversity: return "leaf.fill"
        }
    }

    var color: Color {
        switch self {
        case .wrecks:
            return Color.amber
        case .reefs:
            return Color.reef
        case .caves:
            return Color.trench
        case .walls:
            return Color.lagoon
        case .shore:
            return Color.difficultyBeginner
        case .drift:
            return Color.difficultyIntermediate
        case .beginner:
            return Color.difficultyBeginner
        case .advanced:
            return Color.difficultyAdvanced
        case .nightDiving:
            return Color.ocean
        case .highBiodiversity:
            return Color.seaGreen
        }
    }

    var siteType: DiveSite.SiteType? {
        switch self {
        case .wrecks: return .wreck
        case .reefs: return .reef
        case .caves: return .cave
        case .walls: return .wall
        case .shore: return .shore
        case .drift: return .drift
        default: return nil
        }
    }

    var difficulty: DiveSite.Difficulty? {
        switch self {
        case .beginner: return .beginner
        case .advanced: return .advanced
        default: return nil
        }
    }

    var isNightDiving: Bool {
        self == .nightDiving
    }

    var isHighBiodiversity: Bool {
        self == .highBiodiversity
    }
}
