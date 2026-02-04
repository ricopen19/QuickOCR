import Cocoa

final class SoundService {
    /// 完了音（システムビープ）を再生する
    func playCompletionSound() {
        NSSound.beep()
    }
}
