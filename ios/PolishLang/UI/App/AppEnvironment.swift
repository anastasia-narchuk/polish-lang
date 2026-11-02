import SwiftUI

extension View {
    /// Puts the app model and its stores into the environment of a view tree.
    func appEnvironment(_ app: AppModel) -> some View {
        environment(app)
            .environment(app.settings)
            .environment(app.ai)
            .environment(app.cards)
            .environment(app.mistakes)
            .environment(app.readings)
            .environment(app.reading)
            .environment(app.toasts)
    }
}
