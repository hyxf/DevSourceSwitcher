import Foundation

enum SourceType: String, Codable, CaseIterable, Identifiable {
    case npm = "NPM"
    case pip = "PIP"
    case yarn = "Yarn"
    case git = "Git"

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
        case .git: ".gitconfig"
        }
    }

    var configDirectory: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        switch self {
        case .npm, .yarn, .git:
            return home
        case .pip:
            return home.appendingPathComponent(".pip", isDirectory: true)
        }
    }

    var configPath: URL {
        configDirectory.appendingPathComponent(configFileName)
    }

    var registryKey: String {
        switch self {
        case .npm, .yarn: "registry"
        case .pip: "index-url"
        case .git: "proxy"
        }
    }

    var officialURL: String {
        switch self {
        case .npm: "https://registry.npmjs.org"
        case .pip: "https://pypi.org/simple"
        case .yarn: "https://registry.yarnpkg.com"
        case .git: ""
        }
    }
}
