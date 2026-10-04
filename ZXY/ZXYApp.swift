//  Created by Harsh Kumar on 28/03/26.


import SwiftUI

@main
struct ZXYApp: App {
    @State var dependencies = AppDependencies()
    init() {
        SettingsBloc.bloc.initialise()
    }
    var body: some Scene {
        WindowGroup {
            ContentView(deps: dependencies)
        }
    }
}
