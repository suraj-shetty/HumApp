import Foundation
import Observation

/// Loading state shared by every content screen.
///
/// A single generic enum rather than the usual `isLoading` + `items` + `error`
/// triple: those three booleans permit states that cannot exist (loading *and*
/// failed), and every screen then re-invents the same precedence rules.
enum LoadState<Value: Sendable>: Sendable {
    case idle
    case loading
    case loaded(Value)
    case failed(String)

    var value: Value? {
        if case .loaded(let value) = self { return value }
        return nil
    }

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
}

@MainActor
@Observable
final class HomeViewModel {
    private(set) var recentlyPlayed: LoadState<[HumCollection]> = .idle
    private(set) var recommendations: LoadState<[HumTrack]> = .idle

    private let catalog: MusicCatalogService

    init(environment: AppEnvironment) {
        self.catalog = environment.catalog
    }

    /// Loads both shelves concurrently — they are independent requests, and
    /// running them in series would double the time to first paint.
    func load() async {
        guard case .idle = recentlyPlayed else { return }
        recentlyPlayed = .loading
        recommendations = .loading

        async let recent = catalog.recentlyPlayed()
        async let recommended = catalog.recommendations()

        do {
            recentlyPlayed = .loaded(try await recent)
        } catch {
            recentlyPlayed = .failed("Couldn't load recently played.")
        }
        do {
            recommendations = .loaded(try await recommended)
        } catch {
            recommendations = .failed("Couldn't load recommendations.")
        }
    }

    func reload() async {
        recentlyPlayed = .idle
        await load()
    }

    /// "Sunday evening" — the prototype's greeting overline.
    var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        let partOfDay = switch hour {
        case 5..<12: "morning"
        case 12..<17: "afternoon"
        case 17..<22: "evening"
        default: "night"
        }
        let weekday = Date.now.formatted(.dateTime.weekday(.wide))
        return "\(weekday) \(partOfDay)"
    }
}
