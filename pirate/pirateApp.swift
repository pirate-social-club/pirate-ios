import SwiftUI

@main
struct pirateApp: App {
    @State private var sessionManager = SessionManager()

    init() {
        SessionRefresher.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            ContentView(sessionManager: sessionManager)
                .pirateTheme()
        }
    }
}

struct ContentView: View {
    @Bindable var sessionManager: SessionManager

    var body: some View {
        PirateScaffold(sessionManager: sessionManager)
    }
}

#Preview {
    ContentView(sessionManager: SessionManager())
        .pirateTheme()
}
