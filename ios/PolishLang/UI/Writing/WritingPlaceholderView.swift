import SwiftUI

/// Placeholder of the writing practice for the state exam: the next part of the app.
struct WritingPlaceholderView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.section) {
                    FeatureCard(feature: Theme.writingFeature, title: "Письменная часть экзамена") {
                        Text("Здесь будет подготовка к письменной части экзамена по польскому: тренировка текстов разных типов и разбор ошибок.")
                            .font(.ui(.body))
                            .fixedSize(horizontal: false, vertical: true)
                        Tag(text: "Скоро", style: .neutral)
                    }
                }
                .padding(.horizontal, Theme.Space.screen)
                .padding(.top, 8)
                .padding(.bottom, 32)
                .frame(maxWidth: Theme.maxContentWidth)
                .frame(maxWidth: .infinity)
            }
            .screenBackground()
            .navigationTitle("Письмо")
        }
    }
}
