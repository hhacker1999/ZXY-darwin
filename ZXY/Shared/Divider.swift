//
//  divider.swift
//  LearnSwift
//
//  Created by Harsh Kumar on 29/03/26.
//

import SwiftUI

struct LabeledDivider: View {
    var label: String = ""
    var body: some View {
        if label.isEmpty {
            Rectangle().fill(AppTheme.Colors.divider).frame(height: 1)
        } else {
            HStack(spacing: 12) {
                Rectangle().fill(AppTheme.Colors.divider).frame(height: 1)
                Text(label)
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.elementMuted)
                    .fixedSize()
                Rectangle().fill(AppTheme.Colors.divider).frame(height: 1)
            }
        }
    }
}
