import Foundation
import SwiftUI

@MainActor
@Observable
class ToastProgressBloc {
    static let bloc = ToastProgressBloc()
    private init() {}

    var toastMessage: String?
    var isToastError: Bool = false
    var showLoading: Bool = false

    var toastTask: Task<Void, Never>?

    func showToast(message: String, isError: Bool) {
        toastMessage = message
        isToastError = isError
        #if os(iOS)
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        #endif
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3 * 1_000_000_000)
            if let self = self {
                if !Task.isCancelled {
                    self.toastMessage = nil
                }
            }
        }
    }

    func enableLoading() {
        showLoading = true
    }

    func disableLoading() {
        showLoading = false
    }
}
