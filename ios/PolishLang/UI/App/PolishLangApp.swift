import SwiftUI

@main
struct PolishLangApp: App {
    @State private var model = PolishLangApp.makeModel()

    var body: some Scene {
        WindowGroup {
            root
                .appEnvironment(model)
        }
    }

    @ViewBuilder
    private var root: some View {
        #if DEBUG
        if let screen = DemoMode.screen {
            DemoRoot(screen: screen)
        } else {
            RootView()
        }
        #else
        RootView()
        #endif
    }

    private static func makeModel() -> AppModel {
        #if DEBUG
        if DemoMode.isOn { return DemoMode.makeApp() }
        #endif
        return AppModel(secrets: KeychainStore())
    }
}
