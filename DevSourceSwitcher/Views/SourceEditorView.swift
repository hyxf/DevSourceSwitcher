import SwiftUI

struct SourceEditorView: View {
    enum Mode { case add(SourceType); case edit(SourceItem, SourceType) }
    let mode: Mode; let onSave: (String, String)
        -> Bool; let validationError: String?; let onDismiss: () -> Void

    @State private var name: String = ""
    @State private var protocolType: String = "socks5h://"
    @State private var host: String = ""

    private var sourceType: SourceType {
        switch mode { case let .add(t): return t; case let .edit(_, t): return t }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(sourceType == .git ? "配置代理地址" : "配置源地址").font(.headline)
            Form {
                TextField("名称", text: $name)
                if sourceType == .git {
                    HStack(spacing: 8) {
                        Picker("", selection: $protocolType) {
                            ForEach(
                                ["http://", "https://", "socks5://", "socks5h://"],
                                id: \.self)
                            {
                                Text($0)
                            }
                        }.labelsHidden().frame(width: 100)
                        TextField("127.0.0.1:7891", text: $host)
                    }
                } else {
                    TextField("URL", text: $host)
                }
            }.formStyle(.grouped)

            if let error = validationError { Text(error).font(.caption).foregroundStyle(.red) }

            HStack {
                Spacer()
                Button("取消") { onDismiss() }
                Button("保存") {
                    let cleanedHost = sanitizeHost(host)
                    let finalURL = sourceType == .git ? "\(protocolType)\(cleanedHost)" :
                        cleanedHost
                    if onSave(name, finalURL) { onDismiss() }
                }.disabled(name.isEmpty || host.isEmpty).keyboardShortcut(.defaultAction)
            }
        }
        .padding(20).frame(width: 380)
        .onAppear {
            if case let .edit(item, type) = mode {
                name = item.name
                if type == .git {
                    let protocols = [
                        "socks5h://",
                        "socks5://",
                        "https://",
                        "http://",
                        "socks4://",
                        "socks://"
                    ]
                    if
                        let foundProto = protocols.first(where: { item.url.range(
                            of: $0,
                            options: [.anchored, .caseInsensitive]) != nil })
                    {
                        protocolType = foundProto.lowercased()
                        host = String(item.url.dropFirst(foundProto.count))
                    } else { host = item.url }
                } else { host = item.url }
            }
        }
    }

    private func sanitizeHost(_ input: String) -> String {
        // 增加对尾部斜杠和前后空格的彻底清理
        var trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        let protocols = ["socks5h://", "socks5://", "socks4://", "socks://", "https://", "http://"]
        for proto in protocols {
            if trimmed.range(of: proto, options: [.anchored, .caseInsensitive]) != nil {
                trimmed = String(trimmed.dropFirst(proto.count))
                break
            }
        }
        return trimmed
    }
}
