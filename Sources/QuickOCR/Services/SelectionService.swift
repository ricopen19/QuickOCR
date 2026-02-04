import Foundation
import AppKit

/// 全画面オーバーレイの表示と矩形選択のライフサイクルを管理するサービス
@MainActor
final class SelectionService {
    private var overlayWindow: NSWindow?
    private var fullScreenshot: CGImage?
    private var capturedScreen: NSScreen?

    /// 選択範囲のキャプチャが完了した時のコールバック
    var onCaptured: ((NSImage) -> Void)?
    /// キャンセルされた時のコールバック
    var onCancelled: (() -> Void)?
    /// キャプチャエラーが発生した時のコールバック
    var onError: ((Error) -> Void)?

    /// 全画面オーバーレイを表示し、矩形選択を開始する
    func showOverlay() async {
        guard let screen = screenAtCursor() ?? NSScreen.main else {
            onCancelled?()
            return
        }
        capturedScreen = screen

        let screenshot: CGImage
        do {
            screenshot = try await ScreenCaptureService.captureImage(in: screen.frame)
        } catch {
            onError?(error)
            return
        }
        fullScreenshot = screenshot

        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false,
            screen: screen
        )
        window.level = .screenSaver
        window.isReleasedWhenClosed = false

        let nsImage = NSImage(cgImage: screenshot, size: screen.frame.size)
        let view = SelectionOverlayView(
            screenshot: nsImage,
            frame: CGRect(origin: .zero, size: screen.frame.size)
        )
        view.onComplete = { [weak self] rect in self?.handleSelection(rect) }
        view.onCancel = { [weak self] in
            self?.dismiss()
            self?.onCancelled?()
        }

        window.contentView = view
        window.makeFirstResponder(view)
        window.alphaValue = 0
        window.makeKeyAndOrderFront(nil)
        
        // アニメーション (macOS 14+ async)
        try? await NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            window.animator().alphaValue = 1.0
        }
        
        overlayWindow = window
    }

    // MARK: - Private

    private func dismiss() {
        guard let window = overlayWindow else { return }
        
        // 非同期で閉じるアニメーション
        Task { @MainActor in
            try? await NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                window.animator().alphaValue = 0
            }
            window.close()
        }
        overlayWindow = nil
    }

    private func handleSelection(_ viewRect: CGRect) {
        let screenshot = fullScreenshot
        let screen = capturedScreen
        dismiss()
        fullScreenshot = nil
        capturedScreen = nil

        guard let screenshot = screenshot, let screen = screen else {
            onCancelled?()
            return
        }

        let scale = screen.backingScaleFactor
        let pixelRect = CGRect(
            x: viewRect.origin.x * scale,
            y: viewRect.origin.y * scale,
            width: viewRect.size.width * scale,
            height: viewRect.size.height * scale
        )

        guard let cropped = screenshot.cropping(to: pixelRect) else {
            onCancelled?()
            return
        }

        let image = NSImage(cgImage: cropped, size: viewRect.size)
        onCaptured?(image)
    }

    private func screenAtCursor() -> NSScreen? {
        NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) }
    }
}
