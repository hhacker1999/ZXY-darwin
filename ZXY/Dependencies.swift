import Foundation

@Observable
class AppDependencies {
    let authUc: AuthUsecase
    let mediaUc: MediaUsecase
    let streamUc: StreamUsecase
    let progressUc: ProgressUsecase
    init() {
        authUc = AuthUsecase()
        mediaUc = MediaUsecase()
        streamUc = StreamUsecase()
        progressUc = ProgressUsecase()
    }

}
