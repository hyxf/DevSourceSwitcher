import Foundation

extension Notification.Name {
    static let configDidChange = Notification.Name("ConfigDidChange")
}

/// 负责将 AppConfig 持久化到 Application Support 目录
final class ConfigStorageService {
    static let shared = ConfigStorageService()

    private let fileManager = FileManager.default
    private let encoder: JSONEncoder
    private let decoder = JSONDecoder()

    private init() {
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    // MARK: - Paths

    /// App 专属配置目录（~/Library/Application Support/DevSourceSwitcher/）
    private var configDirectory: URL {
        get throws {
            guard
                let appSupport = fileManager.urls(
                    for: .applicationSupportDirectory,
                    in: .userDomainMask).first else
            {
                throw ConfigError.directoryCreationFailed("无法定位 Application Support 目录")
            }
            return appSupport.appendingPathComponent("DevSourceSwitcher", isDirectory: true)
        }
    }

    private var configURL: URL {
        get throws {
            try configDirectory.appendingPathComponent("config.json")
        }
    }

    // MARK: - Public API

    /// 加载配置；若文件不存在或损坏则写入并返回默认配置
    func load() -> AppConfig {
        guard
            let url = try? configURL,
            fileManager.fileExists(atPath: url.path),
            let data = try? Data(contentsOf: url),
            let config = try? decoder.decode(AppConfig.self, from: data) else
        {
            let defaults = AppConfig.defaultConfig()
            try? save(defaults) // 首次运行时落盘，失败不影响使用
            return defaults
        }
        return config
    }

    /// 将配置原子写入磁盘；目录不存在时自动创建
    func save(_ config: AppConfig) throws {
        let url = try configURL
        let dir = url.deletingLastPathComponent()

        if !fileManager.fileExists(atPath: dir.path) {
            try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }

        let data = try encoder.encode(config)
        try data.write(to: url, options: .atomic)

        // 发送配置变更通知，以便菜单栏等组件同步刷新
        NotificationCenter.default.post(name: .configDidChange, object: nil)
    }
}
