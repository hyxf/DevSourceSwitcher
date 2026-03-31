import SwiftUI

struct SourceEditorView: View {
    enum Mode {
        case add(SourceType)
        case edit(SourceItem, SourceType)
    }

    let mode: Mode
    let onSave: (String, String) -> Bool
    let validationError: String?
    let onDismiss: () -> Void

    @State private var name: String = ""
    @State private var protocolType: String = "socks5h://"
    @State private var host: String = ""

    private var title: String {
        switch mode {
        case let .add(type): "新增 \(type.displayName) 源"
        case let .edit(item, type): "编辑 \(type.displayName) 源：\(item.name)"
        }
    }

    private var sourceType: SourceType {
        switch mode {
        case let .add(t): t
        case let .edit(_, t): t
        }
    }

    private var isSaveDisabled: Bool {
        name.trimmingCharacters(in: .whitespaces).isEmpty ||
            host.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(title).font(.headline)

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
                        }
                        .labelsHidden()
                        .frame(width: 100)

                        TextField("127.0.0.1:7891", text: $host)
                    }
                } else {
                    TextField("URL（https://...）", text: $host)
                }
            }
            .formStyle(.grouped)

            Group {
                if let error = validationError {
                    Text(error).font(.footnote).foregroundStyle(.red)
                } else {
                    Text(" ").font(.footnote)
                }
            }

            HStack {
                Spacer()
                Button("取消") { onDismiss() }
                    .keyboardShortcut(.cancelAction)

                Button("保存") {
                    let finalURL = sourceType == .git ?
                        "\(protocolType)\(host.trimmingCharacters(in: .whitespaces))" : host
                        .trimmingCharacters(in: .whitespaces)
                    if onSave(name, finalURL) { onDismiss() }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(isSaveDisabled)
            }
        }
        .padding(20)
        .frame(width: 380)
        .onAppear {
            if case let .edit(item, type) = mode {
                name = item.name
                if type == .git {
                    let protocols = ["socks5h://", "socks5://", "https://", "http://"]
                    if let proto = protocols.first(where: { item.url.hasPrefix($0) }) {
                        protocolType = proto
                        host = String(item.url.dropFirst(proto.count))
                    } else {
                        host = item.url
                    }
                } else {
                    host = item.url
                }
            }
        }
    }
}
