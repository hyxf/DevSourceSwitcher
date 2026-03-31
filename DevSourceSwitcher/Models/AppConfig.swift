import Foundation

struct AppConfig: Codable {
    var npmSources: [SourceItem]
    var yarnSources: [SourceItem]
    var pipSources: [SourceItem]
    var defaultNpmSourceId: UUID
    var defaultYarnSourceId: UUID
    var defaultPipSourceId: UUID

    static func defaultConfig() -> AppConfig {
        // ------
        let npmOfficial = SourceItem(
            name: "官方源",
            url: "https://registry.npmjs.org",
            isBuiltIn: true)
        let npmAliyun = SourceItem(
            name: "阿里源",
            url: "https://registry.npmmirror.com",
            isBuiltIn: true)
        // ------
        let yarnOfficial = SourceItem(
            name: "官方源",
            url: "https://registry.yarnpkg.com",
            isBuiltIn: true)
        let yarnAliyun = SourceItem(
            name: "阿里源",
            url: "https://registry.npmmirror.com",
            isBuiltIn: true)
        // ------
        let pipOfficial = SourceItem(name: "官方源", url: "https://pypi.org/simple/", isBuiltIn: true)
        let pipTsinghua = SourceItem(
            name: "清华源",
            url: "https://pypi.tuna.tsinghua.edu.cn/simple/",
            isBuiltIn: true)
        let pipAliyun = SourceItem(
            name: "阿里源",
            url: "http://mirrors.aliyun.com/pypi/simple/",
            isBuiltIn: true)

        return AppConfig(
            npmSources: [npmOfficial, npmAliyun],
            yarnSources: [yarnOfficial, yarnAliyun],
            pipSources: [pipOfficial, pipAliyun, pipTsinghua],
            defaultNpmSourceId: npmAliyun.id,
            defaultYarnSourceId: yarnAliyun.id,
            defaultPipSourceId: pipAliyun.id)
    }

    /// 当前默认 NPM 源；若 ID 失效则回退到第一项
    var defaultNpmSource: SourceItem? {
        npmSources.first { $0.id == defaultNpmSourceId } ?? npmSources.first
    }

    /// 当前默认 Yarn 源；若 ID 失效则回退到第一项
    var defaultYarnSource: SourceItem? {
        yarnSources.first { $0.id == defaultYarnSourceId } ?? yarnSources.first
    }

    /// 当前默认 PIP 源；若 ID 失效则回退到第一项
    var defaultPipSource: SourceItem? {
        pipSources.first { $0.id == defaultPipSourceId } ?? pipSources.first
    }

    /// 根据类型取对应源列表
    func sources(for type: SourceType) -> [SourceItem] {
        switch type {
        case .npm: npmSources
        case .yarn: yarnSources
        case .pip: pipSources
        }
    }

    /// 根据类型取当前默认源
    func defaultSource(for type: SourceType) -> SourceItem? {
        switch type {
        case .npm: defaultNpmSource
        case .yarn: defaultYarnSource
        case .pip: defaultPipSource
        }
    }

    /// 根据类型取默认源 ID
    func defaultSourceId(for type: SourceType) -> UUID {
        switch type {
        case .npm: defaultNpmSourceId
        case .yarn: defaultYarnSourceId
        case .pip: defaultPipSourceId
        }
    }

    /// 将 url 规范化后在源列表里匹配，返回匹配到的源 ID。
    func matchedSourceId(for type: SourceType, url: String) -> UUID? {
        let normalized = SourceItem(name: "", url: url).normalizedURL
        return sources(for: type).first { $0.normalizedURL == normalized }?.id
    }
}
