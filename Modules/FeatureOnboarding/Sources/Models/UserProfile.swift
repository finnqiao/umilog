import Foundation

/// User's diving experience level
public enum ExperienceLevel: String, CaseIterable, Codable, Identifiable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"
    case divemaster = "Divemaster"

    public var id: String { rawValue }

    public var description: String {
        switch self {
        case .beginner:
            return "New to diving or fewer than 20 dives"
        case .intermediate:
            return "Comfortable diver with 20-100 dives"
        case .advanced:
            return "Experienced diver with 100+ dives"
        case .divemaster:
            return "Professional level diver"
        }
    }

    public var iconName: String {
        switch self {
        case .beginner:
            return "figure.pool.swim"
        case .intermediate:
            return "water.waves"
        case .advanced:
            return "arrow.down.to.line"
        case .divemaster:
            return "star.fill"
        }
    }
}

/// Diving certifications
public enum Certification: String, CaseIterable, Codable, Identifiable {
    case openWater = "Open Water"
    case advancedOpenWater = "Advanced Open Water"
    case rescue = "Rescue Diver"
    case divemaster = "Divemaster"
    case instructor = "Instructor"
    case nitrox = "Nitrox"
    case deepDiver = "Deep Diver"
    case wreckDiver = "Wreck Diver"

    public var id: String { rawValue }

    public var shortName: String {
        switch self {
        case .openWater: return "OW"
        case .advancedOpenWater: return "AOW"
        case .rescue: return "Rescue"
        case .divemaster: return "DM"
        case .instructor: return "Inst"
        case .nitrox: return "EANx"
        case .deepDiver: return "Deep"
        case .wreckDiver: return "Wreck"
        }
    }

    public var iconName: String {
        switch self {
        case .openWater: return "checkmark.seal"
        case .advancedOpenWater: return "checkmark.seal.fill"
        case .rescue: return "cross.fill"
        case .divemaster: return "star.fill"
        case .instructor: return "person.badge.shield.checkmark"
        case .nitrox: return "aqi.medium"
        case .deepDiver: return "arrow.down.circle.fill"
        case .wreckDiver: return "ferry.fill"
        }
    }
}

/// User's diving profile stored in UserDefaults
public struct UserProfile: Codable, Equatable {
    public var experienceLevel: ExperienceLevel?
    public var certifications: Set<Certification>
    public var divingStartDate: Date?
    public var prefersDarkTheme: Bool

    public init(
        experienceLevel: ExperienceLevel? = nil,
        certifications: Set<Certification> = [],
        divingStartDate: Date? = nil,
        prefersDarkTheme: Bool = true
    ) {
        self.experienceLevel = experienceLevel
        self.certifications = certifications
        self.divingStartDate = divingStartDate
        self.prefersDarkTheme = prefersDarkTheme
    }

    // MARK: - UserDefaults Keys

    private static let storageKey = "app.umilog.user.profile"

    // MARK: - Persistence

    public func save(to defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    public static func load(from defaults: UserDefaults = .standard) -> UserProfile {
        guard let data = defaults.data(forKey: storageKey),
              let profile = try? JSONDecoder().decode(UserProfile.self, from: data) else {
            return UserProfile()
        }
        return profile
    }

    public static func clear(from defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: storageKey)
    }
}
