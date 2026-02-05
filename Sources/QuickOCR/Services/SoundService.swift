import Cocoa

final class SoundService {
    /// 完了音（システムビープ）を再生する
    func playCompletionSound() {
        if let sound = NSSound(named: "Glass") {
            sound.play()
        } else {
            NSSound.beep()
        }
    }
}
