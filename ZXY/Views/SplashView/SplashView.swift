//
//  SplashView.swift
//
//  Created by Harsh Kumar on 31/03/26.
//

import Foundation
import SwiftUI

struct SplashView: View {
    let vm: SplashViewModel
    init(mediaUc: MediaUsecase, authUc: AuthUsecase) {
        vm = SplashViewModel(mediaUc: mediaUc, authUc: authUc)
    }

    var body: some View {
        ZStack {
            Color(.black).ignoresSafeArea()
            VStack {
                Text("splash view").foregroundStyle(.white)
                Spacer(minLength: 16)
                if vm.err != nil {
                    Text(vm.err!).foregroundStyle(.red)
                }
            }
        }.background(.black).onAppear(perform: {
            Task {
                await vm.initialise()
            }
        })
    }
}

#Preview {
    SplashView(mediaUc: MediaUsecase(), authUc: AuthUsecase())
}
