//
//  LearnSwiftApp.swift
//  LearnSwift
//
//  Created by Harsh Kumar on 28/03/26.
//

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
                .onAppear {
                    #if DEBUG
                        Bundle(
                            path:
                                "/Applications/InjectionIII.app/Contents/Resources/iOSInjection.bundle"
                        )?.load()
                        // for tvOS:
                        Bundle(
                            path:
                                "/Applications/InjectionIII.app/Contents/Resources/tvOSInjection.bundle"
                        )?.load()
                        // Or for macOS:
                        Bundle(
                            path:
                                "/Applications/InjectionIII.app/Contents/Resources/macOSInjection.bundle"
                        )?.load()
                    #endif
                }
        }
        .windowStyle(.hiddenTitleBar)
    }
}
