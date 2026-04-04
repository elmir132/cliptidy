import Foundation

/// Persists the chosen options in UserDefaults. A missing or corrupt value falls back
/// to the standard options instead of failing.
public struct OptionsStore {
    private let defaults: UserDefaults
    private let key = "cleanOptions.v1"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> CleanOptions {
        guard let data = defaults.data(forKey: key),
              let options = try? JSONDecoder().decode(CleanOptions.self, from: data)
        else { return .standard }
        return options
    }

    public func save(_ options: CleanOptions) {
        if let data = try? JSONEncoder().encode(options) {
            defaults.set(data, forKey: key)
        }
    }
}
