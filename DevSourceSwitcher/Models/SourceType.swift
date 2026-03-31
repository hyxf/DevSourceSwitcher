import Foundation

enum SourceType: String, Codable, CaseIterable, Identifiable {
    case npm = "NPM"
    case pip = "PIP"
    case yarn = "Yarn"

    var id: String {
        rawValue
    }

    var displayName: String {
        rawValue
    }

    var configFileName: String {
        switch self {
        case .npm: ".npmrc"
        case .pip: "pip.conf"
        case .yarn: ".yarnrc"
        }
    }

    var configDirectory: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        switch self {
        case .npm:
            return home
        case .pip:
            return home.appendingPathComponent(".pip", isDirectory: true)
        case .yarn:
            return home
        }
    }

    var configPath: URL {
        configDirectory.appendingPathComponent(configFileName)
    }

    var registryKey: String {
        switch self {
        case .npm: "registry"
        case .pip: "index-url"
        case .yarn: "registry"
        }
    }

    var officialURL: String {
        switch self {
        case .npm: "https://registry.npmjs.org"
        case .pip: "https://pypi.org/simple"
        case .yarn: "https://registry.yarnpkg.com"
        }
    }
}
