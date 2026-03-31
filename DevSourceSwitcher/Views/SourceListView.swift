import SwiftUI

struct SourceListView: View {
    let sourceType: SourceType
    @ObservedObject var viewModel: SettingsViewModel

    @State private var selectedSource: SourceItem?
    @State private var showAddSheet = false
    @State private var editingSource: SourceItem?

    var body: some View {
        VStack(spacing: 0) {
            sourceList
            Divider()
            toolbar
        }
        .sheet(isPresented: $showAddSheet, onDismiss: { viewModel.clearValidationError() }) {
            SourceEditorView(
                mode: .add(sourceType),
                onSave: { name, url in
                    viewModel.addSource(type: sourceType, name: name, url: url)
                },
                validationError: viewModel.validationError,
                onDismiss: { showAddSheet = false })
        }
        .sheet(item: $editingSource, onDismiss: { viewModel.clearValidationError() }) { source in
            SourceEditorView(
                mode: .edit(source, sourceType),
                onSave: { name, url in
                    viewModel.updateSource(type: sourceType, id: source.id, name: name, url: url)
                },
                validationError: viewModel.validationError,
                onDismiss: { editingSource = nil })
        }
    }

    // MARK: - Subviews

    private var sourceList: some View {
        List(viewModel.sources(for: sourceType), selection: $selectedSource) { source in
            SourceRowView(
                source: source,
                isDefault: source.id == viewModel.activeSourceId(for: sourceType))
                .tag(source)
        }
        .listStyle(.inset)
        .scrollContentBackground(.hidden)
    }

    private var toolbar: some View {
        HStack(spacing: 0) {
            toolbarButton(icon: "plus") {
                showAddSheet = true
            }
            Divider().frame(height: 16)
            toolbarButton(icon: "minus", disabled: selectedSource?.isBuiltIn != false) {
                if let s = selectedSource { viewModel.deleteSource(type: sourceType, item: s) }
            }
            Divider().frame(height: 16)
            toolbarButton(
                icon: "pencil",
                disabled: selectedSource == nil || selectedSource?.isBuiltIn == true)
            {
                editingSource = selectedSource
            }
            Spacer()
        }
        .background(Color.primary.opacity(0.02))
    }

    private func toolbarButton(
        icon: String,
        disabled: Bool = false,
        action: @escaping () -> Void) -> some View
    {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .frame(width: 36, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }
}

// MARK: - SourceRowView

struct SourceRowView: View {
    let source: SourceItem
    let isDefault: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(source.name).font(.system(size: 13, weight: .medium))

                    if source.isBuiltIn {
                        Text("系统")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .background(Capsule().stroke(
                                Color.secondary.opacity(0.3),
                                lineWidth: 0.5))
                            .foregroundStyle(.secondary)
                    }
                }
                Text(source.url)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            if isDefault {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.green.opacity(0.8))
            }
        }
        .padding(.vertical, 5)
    }
}
