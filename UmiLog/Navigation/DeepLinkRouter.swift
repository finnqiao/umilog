import Foundation
import SwiftUI
import os

/// Handles deep link URL parsing and navigation for the app.
/// Supports `umilog://` URL scheme with routes for dives, sites, species, and tabs.
@MainActor
final class DeepLinkRouter: ObservableObject {
    static let shared = DeepLinkRouter()

    /// The pending deep link destination to navigate to
    @Published var pendingDestination: DeepLinkDestination?

    private let logger = Logger(subsystem: "app.umilog", category: "DeepLinkRouter")

    private init() {}

    /// Parses a URL and returns the corresponding destination
    /// - Parameter url: The deep link URL to parse
    /// - Returns: The destination if the URL is valid, nil otherwise
    func parse(_ url: URL) -> DeepLinkDestination? {
        guard url.scheme == "umilog" else {
            logger.warning("Invalid URL scheme: \(url.scheme ?? "nil", privacy: .public)")
            return nil
        }

        let host = url.host ?? ""
        let pathComponents = url.pathComponents.filter { $0 != "/" }

        logger.info("Parsing deep link: host=\(host, privacy: .public), path=\(pathComponents, privacy: .public)")

        switch host {
        case "dive":
            guard let id = pathComponents.first else {
                logger.warning("Missing dive ID in URL")
                return nil
            }
            return .dive(id: id)

        case "site":
            guard let id = pathComponents.first else {
                logger.warning("Missing site ID in URL")
                return nil
            }
            return .site(id: id)

        case "species":
            guard let id = pathComponents.first else {
                logger.warning("Missing species ID in URL")
                return nil
            }
            return .species(id: id)

        case "tab":
            guard let tabName = pathComponents.first,
                  let tab = Tab(rawValue: tabName) else {
                logger.warning("Invalid tab name in URL: \(pathComponents.first ?? "nil", privacy: .public)")
                return nil
            }
            return .tab(tab)

        case "log":
            // Quick access to log launcher
            return .logLauncher

        default:
            logger.warning("Unknown deep link host: \(host, privacy: .public)")
            return nil
        }
    }

    /// Handles an incoming URL by parsing and setting the pending destination
    /// - Parameter url: The deep link URL to handle
    /// - Returns: True if the URL was successfully parsed
    @discardableResult
    func handle(_ url: URL) -> Bool {
        guard let destination = parse(url) else {
            return false
        }

        logger.info("Handling deep link: \(String(describing: destination), privacy: .public)")
        pendingDestination = destination
        return true
    }

    /// Clears the pending destination after navigation is complete
    func clearPendingDestination() {
        pendingDestination = nil
    }
}

/// Represents a deep link navigation destination
enum DeepLinkDestination: Equatable, Hashable {
    /// Navigate to a specific dive log
    case dive(id: String)

    /// Navigate to a specific dive site on the map
    case site(id: String)

    /// Navigate to a specific species detail
    case species(id: String)

    /// Switch to a specific tab
    case tab(Tab)

    /// Open the log launcher sheet
    case logLauncher
}

// MARK: - URL Generation

extension DeepLinkDestination {
    /// Generates a shareable URL for this destination
    var url: URL? {
        switch self {
        case .dive(let id):
            return URL(string: "umilog://dive/\(id)")
        case .site(let id):
            return URL(string: "umilog://site/\(id)")
        case .species(let id):
            return URL(string: "umilog://species/\(id)")
        case .tab(let tab):
            return URL(string: "umilog://tab/\(tab.rawValue)")
        case .logLauncher:
            return URL(string: "umilog://log")
        }
    }
}
