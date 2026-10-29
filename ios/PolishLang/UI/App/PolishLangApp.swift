import SwiftUI

@main
struct PolishLangApp: App {
    @State private var model = AppModel(secrets: KeychainStore())

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .environment(model.settings)
                .environment(model.ai)
                .environment(model.cards)
                .environment(model.mistakes)
                .environment(model.readings)
                .environment(model.reading)
                .environment(model.toasts)
        }
    }
}
