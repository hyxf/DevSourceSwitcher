import SwiftUI

struct SourceEditorView: View {
    enum Mode {
        case add(SourceType)
        case edit(SourceItem, SourceType)
    }

    let mode: Mode
    /// 保存回调；返回 false 表示验证失败（错误由外部传入的 validationError 提供）
    let onSave: (String, String) -> Bool
    /// 由 ViewModel 提供的验证错误，外部传入保证同步
    let validationError: String?
    let onDismiss: () -> Void

    @State private var name: String = ""
    @State private var url: String = ""

    private var title: String {
        switch mode {
        case let .add(type): "新增 \(type.displayName) 源"
        case let .edit(item, type): "编辑 \(type.displayName) 源：\(item.name)"
        }
    }

    private var isSaveDisabled: Bool {
        name.trimmingCharacters(in: .whitespaces).isEmpty ||
            url.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title).font(.headline)

            Form {
                TextField("名称", text: $name)
                TextField("URL（https://...）", text: $url)
            }
            .formStyle(.grouped)

            // 验证错误提示——占位文本保持布局高度稳定，避免弹跳
            Group {
                if let error = validationError {
                    Text(error).font(.caption).foregroundStyle(.red)
                } else {
                    Text(" ").font(.caption)
                }
            }

            HStack {
                Spacer()
                Button("取消") { onDismiss() }
                    .keyboardShortcut(.cancelAction)

                Button("保存") {
                    if onSave(name, url) { onDismiss() }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(isSaveDisabled)
            }
        }
        .padding(20)
        .frame(width: 380)
        .onAppear {
            if case let .edit(item, _) = mode {
                name = item.name
                url = item.url
            }
        }
    }
}
