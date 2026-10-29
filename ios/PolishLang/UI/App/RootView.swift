import SwiftUI

/// The menu: reading, cards, writing (to come) and settings.
struct RootView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        @Bindable var app = app
        TabView(selection: $app.tab) {
            ReadingTab()
                .tabItem { Label("Чтение", systemImage: "book") }
                .tag(AppModel.Tab.reading)
            CardsTab()
                .tabItem { Label("Карточки", systemImage: "rectangle.on.rectangle.angled") }
                .tag(AppModel.Tab.cards)
            WritingPlaceholderView()
                .tabItem { Label("Письмо", systemImage: "square.and.pencil") }
                .tag(AppModel.Tab.writing)
            SettingsView()
                .tabItem { Label("Настройки", systemImage: "gearshape") }
                .tag(AppModel.Tab.settings)
        }
        .toastOverlay(bottomPadding: 64)
    }
}
