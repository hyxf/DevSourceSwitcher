import Foundation

struct AppConfig: Codable {
    var npmSources: [SourceItem]
    var yarnSources: [SourceItem]
    var pipSources: [SourceItem]
    var gitSources: [SourceItem]
    var defaultNpmSourceId: UUID
    var defaultYarnSourceId: UUID
    var defaultPipSourceId: UUID
    var defaultGitSourceId: UUID
    var gitOnlyGithub: Bool

    enum CodingKeys: String, CodingKey {
        case npmSources, yarnSources, pipSources, gitSources
        case defaultNpmSourceId, defaultYarnSourceId, defaultPipSourceId, defaultGitSourceId
        case gitOnlyGithub
    }

    init(
        npmSources: [SourceItem],
        yarnSources: [SourceItem],
        pipSources: [SourceItem],
        gitSources: [SourceItem],
        defaultNpmSourceId: UUID,
        defaultYarnSourceId: UUID,
        defaultPipSourceId: UUID,
        defaultGitSourceId: UUID,
        gitOnlyGithub: Bool)
    {
        self.npmSources = npmSources
        self.yarnSources = yarnSources
        self.pipSources = pipSources
        self.gitSources = gitSources
        self.defaultNpmSourceId = defaultNpmSourceId
        self.defaultYarnSourceId = defaultYarnSourceId
        self.defaultPipSourceId = defaultPipSourceId
        self.defaultGitSourceId = defaultGitSourceId
        self.gitOnlyGithub = gitOnlyGithub
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        npmSources = try container.decode([SourceItem].self, forKey: .npmSources)
        pipSources = try container.decode([SourceItem].self, forKey: .pipSources)
        defaultNpmSourceId = try container.decode(UUID.self, forKey: .defaultNpmSourceId)
        defaultPipSourceId = try container.decode(UUID.self, forKey: .defaultPipSourceId)

        let defaults = AppConfig.defaultConfig()
        yarnSources = (try? container.decode([SourceItem].self, forKey: .yarnSources)) ?? defaults
            .sources
        defaultYarnSourceId = (try? container.decode(UUID.self, forKey: .defaultYarnSourceId)) ??
            defaults.defaultId

        gitSources = (try? container.decode([SourceItem].self, forKey: .gitSources)) ?? defaults.gitSources
        defaultGitSourceId = (try? container.decode(UUID.self, forKey: .defaultGitSourceId)) ?? defaults.defaultGitSourceId
        gitOnlyGithub = (try? container.decode(Bool.self, forKey: .gitOnlyGithub)) ?? true
    }

    static func defaultConfig() -> AppConfig {
        let npmOfficial = SourceItem(
            name: "官方源",
            url: "https://registry.npmjs.org",
            isBuiltIn: true)
        let npmAliyun = SourceItem(
            name: "阿里源",
            url: "https://registry.npmmirror.com",
            isBuiltIn: true)
        let yarn = defaultYarnSources()
        let pipOfficial = SourceItem(name: "官方源", url: "https://pypi.org/simple/", isBuiltIn: true)
        let pipAliyun = SourceItem(
            name: "阿里源",
            url: "http://mirrors.aliyun.com/pypi/simple/",
            isBuiltIn: true)
        let gitDefault = SourceItem(
            name: "本地 SOCKS5",
            url: "socks5h://127.0.0.1:7891",
            isBuiltIn: true)

        return AppConfig(
            npmSources: [npmOfficial, npmAliyun],
            yarnSources: yarn.sources,
            pipSources: [pipOfficial, pipAliyun],
            gitSources: [gitDefault],
            defaultNpmSourceId: npmAliyun.id,
            defaultYarnSourceId: yarn.defaultId,
            defaultPipSourceId: pipAliyun.id,
            defaultGitSourceId: gitDefault.id,
            gitOnlyGithub: true)
    }

    static func defaultYarnSources() -> (sources: [SourceItem], defaultId: UUID) {
        let yarnOfficial = SourceItem(
            name: "官方源",
            url: "https://registry.yarnpkg.com",
            isBuiltIn: true)
        let yarnAliyun = SourceItem(
            name: "阿里源",
            url: "https://registry.npmmirror.com",
            isBuiltIn: true)
        return (sources: [yarnOfficial, yarnAliyun], defaultId: yarnAliyun.id)
    }

    var defaultNpmSource: SourceItem? {
        npmSources.first { $0.id == defaultNpmSourceId } ?? npmSources.first
    }

    var defaultYarnSource: SourceItem? {
        yarnSources.first { $0.id == defaultYarnSourceId } ?? yarnSources.first
    }

    var defaultPipSource: SourceItem? {
        pipSources.first { $0.id == defaultPipSourceId } ?? pipSources.first
    }

    var defaultGitSource: SourceItem? {
        gitSources.first { $0.id == defaultGitSourceId } ?? gitSources.first
    }

    func sources(for type: SourceType) -> [SourceItem] {
        switch type {
        case .npm: npmSources case .yarn: yarnSources case .pip: pipSources case .git: gitSources
        }
    }

    func defaultSource(for type: SourceType) -> SourceItem? {
        switch type {
        case .npm: defaultNpmSource case .yarn: defaultYarnSource case .pip: defaultPipSource case .git: defaultGitSource
        }
    }

    func defaultSourceId(for type: SourceType) -> UUID {
        switch type {
        case .npm: defaultNpmSourceId case .yarn: defaultYarnSourceId case .pip: defaultPipSourceId case .git: defaultGitSourceId
        }
    }

    func matchedSourceId(for type: SourceType, url: String) -> UUID? {
        let normalized = SourceItem(name: "", url: url).normalizedURL
        return sources(for: type).first { $0.normalizedURL == normalized }?.id
    }
}
