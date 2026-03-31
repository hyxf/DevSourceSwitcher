import SwiftUI

struct SourceDetailView: View {
    @ObservedObject var viewModel: SettingsViewModel
    let type: SourceType

    var body: some View {
        VStack(spacing: 0) {
            SourceSectionView(type: type, viewModel: viewModel)
        }
        .padding(.horizontal, 40)
        .padding(.top, 20)
        .padding(.bottom, 8) // 底部间距收缩至 8
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
