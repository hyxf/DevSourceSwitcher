import Foundation

/// 负责对配置文件进行备份与还原（.backup 后缀同目录存放）
final class BackupService {
    static let shared = BackupService()
    private let fileManager = FileManager.default

    private init() {}

    // MARK: - Public API

    /// 将 filePath 备份为 filePath.backup；若源文件不存在则静默跳过
    func backup(filePath: String) {
        guard fileManager.fileExists(atPath: filePath) else { return }
        let backupPath = filePath + ".backup"
        do {
            if fileManager.fileExists(atPath: backupPath) {
                try fileManager.removeItem(atPath: backupPath)
            }
            try fileManager.copyItem(atPath: filePath, toPath: backupPath)
        } catch {
            // 备份失败不阻断主流程，记录日志即可
            print("[BackupService] 备份失败 '\(filePath)': \(error.localizedDescription)")
        }
    }

    /// 从 filePath.backup 还原到 filePath；若备份文件不存在则抛出错误
    func restore(filePath: String) throws {
        let backupPath = filePath + ".backup"
        guard fileManager.fileExists(atPath: backupPath) else {
            throw ConfigError.fileNotFound("备份文件不存在: \(backupPath)")
        }
        if fileManager.fileExists(atPath: filePath) {
            try fileManager.removeItem(atPath: filePath)
        }
        try fileManager.copyItem(atPath: backupPath, toPath: filePath)
    }
}
