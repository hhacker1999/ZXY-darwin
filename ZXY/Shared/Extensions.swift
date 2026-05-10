//
//  Extensions.swift
//  LearnSwift
//
//  Created by Harsh Kumar on 29/03/26.
//

import SwiftUI

extension View {
    func placeholder<C: View>(when show: Bool, @ViewBuilder placeholder: () -> C) -> some View {
        ZStack(alignment: .leading) {
            if show { placeholder() }
            self
        }
    }
    func wrapInBg() -> some View {
        ZStack { Constants.bgColor.ignoresSafeArea(); self }
    }
}
