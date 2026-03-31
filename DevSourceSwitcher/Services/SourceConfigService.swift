import Foundation

/// 所有 registry 操作服务必须实现的协议（便于测试时 mock）
protocol SourceConfigServiceProtocol {
    func switchRegistry(to source: SourceItem?, for type: SourceType) throws
    func currentRegistryURL(for type: SourceType) -> String?
}

/// 配置操作过程中的结构化错误
enum ConfigError: LocalizedError {
    case invalidURL(String)
    case fileWriteFailed(String)
    case directoryCreationFailed(String)
    case fileNotFound(String)

    var errorDescription: String? {
        switch self {
        case let .invalidURL(url): "无效的源 URL：\(url)"
        case let .fileWriteFailed(path): "写入配置文件失败：\(path)"
        case let .directoryCreationFailed(path): "无法创建目录：\(path)"
        case let .fileNotFound(path): "文件不存在：\(path)"
        }
    }
}
