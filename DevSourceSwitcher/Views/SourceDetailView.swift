import SwiftUI

struct SourceDetailView: View {
    @ObservedObject var viewModel: SettingsViewModel
    let type: SourceType

    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                SourceSectionView(type: type, viewModel: viewModel)
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 24)
        }
    }
}
