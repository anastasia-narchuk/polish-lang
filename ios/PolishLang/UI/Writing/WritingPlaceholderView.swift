import SwiftUI

/// Placeholder of the writing practice for the state exam: the next part of the app.
struct WritingPlaceholderView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label("Скоро", systemImage: "square.and.pencil")
            } description: {
                Text("Здесь будет подготовка к письменной части экзамена по польскому: тренировка текстов разных типов и разбор ошибок.")
            }
            .navigationTitle("Письмо")
        }
    }
}
