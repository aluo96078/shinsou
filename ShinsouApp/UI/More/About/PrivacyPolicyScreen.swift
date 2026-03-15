import SwiftUI
import ShinsouI18n

struct PrivacyPolicyScreen: View {

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(MR.strings.privacyTitle)
                    .font(.title2)
                    .fontWeight(.bold)

                Text(MR.strings.privacyLastUpdated)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(MR.strings.privacyIntro)

                sectionView(MR.strings.privacySection1Title, MR.strings.privacySection1Body)
                sectionView(MR.strings.privacySection2Title, MR.strings.privacySection2Body)
                sectionView(MR.strings.privacySection3Title, MR.strings.privacySection3Body)
                sectionView(MR.strings.privacySection4Title, MR.strings.privacySection4Body)
                sectionView(MR.strings.privacySection5Title, MR.strings.privacySection5Body)
            }
            .padding()
        }
        .navigationTitle(MR.strings.aboutPrivacyPolicy)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func sectionView(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(body)
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }
}
