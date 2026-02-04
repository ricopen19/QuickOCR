# QuickOCR アーキテクチャ（確定版）

**Status**: Phase 3 パフォーマンス最適化 完了
**Last Updated**: 2026-02-04

---

## プロジェクト構成

### Package.swift
- `swift-tools-version: 6.0`（`.macOS(.v15)` には 6.0 が必要）
- Platform: `.macOS(.v14)`
- Targets:
  - `QuickOCR` (library) — 全ビジネスロジック
  - `QuickOCRApp` (executable) — `@main` エントリーポイント。`import QuickOCR`のみ
  - `QuickOCRTests` (test) — `@testable import QuickOCR`

> **分割理由**: `@main` と XCTest のエントリポイント衝突を回避するため、executable は薄いラッパーに分離

### ディレクトリ構造（実際）

```
Sources/
├── QuickOCR/                  # Library target
│   ├── App/
│   │   └── AppDelegate.swift  # @MainActor、全サービスの生成と接続
│   ├── Models/
│   │   ├── OCRResult.swift
│   │   └── AppSettings.swift          # ModifierKey・KeyBinding・AppSettings
│   ├── Services/
│   │   ├── HotkeyService.swift        # CGEventTap ベース（動的キー切り替え対応）
│   │   ├── OCRService.swift           # Vision Framework
│   │   ├── ClipboardService.swift     # NSPasteboard
│   │   ├── NotificationService.swift  # UNUserNotificationCenter
│   │   ├── PermissionService.swift    # 設定画面ディープリンク
│   │   ├── ScreenCaptureService.swift # ScreenCaptureKit
│   │   ├── SelectionService.swift     # オーバーレイライフサイクル管理
│   │   ├── SettingsService.swift      # UserDefaults永続化
│   │   ├── TextFormatService.swift    # 改行正規化
│   │   ├── SoundService.swift         # NSSound.beep()
│   │   ├── LaunchAtLoginService.swift # SMAppService ラッパー
│   │   └── ShortcutConflictChecker.swift # 既知ショートカット照合
│   └── Views/
│       ├── SelectionOverlayView.swift # 矩形選択NSView
│       └── SettingsView.swift         # 設定画面 + ShortcutRecorder
└── QuickOCRApp/               # Executable target
    └── QuickOCRApp.swift      # @main, MenuBarExtra

Tests/
└── QuickOCRTests/
    ├── OCRServiceTests.swift          # 6件
    ├── ClipboardServiceTests.swift    # 5件
    ├── NotificationServiceTests.swift # 9件（truncate検証）
    ├── HotkeyServiceTests.swift       # 4件（安全性検証）
    ├── TextFormatServiceTests.swift   # 8件
    └── SettingsServiceTests.swift     # 4件
```

---

## データフロー（確定）

```
Cmd+Shift+O
  ↓
HotkeyService (CGEventTap callback → main run loop)
  ↓ Task { @MainActor in ... }
AppDelegate.startOCRFlow()
  ↓
SelectionService.showOverlay()
  ├── ScreenCaptureService.captureImage(in: screen.frame)  → fullScreenshot
  └── SelectionOverlayView 表示（fullScreenshot を暗転で描画）
        ↓ マウスドラッグで矩形選択
        ↓ mouseUp
  SelectionService.handleSelection(viewRect)
  ├── fullScreenshot.cropping(to: pixelRect)  → 選択範囲画像
  └── onCaptured callback
        ↓
AppDelegate.runOCR(on: image)
  ├── OCRService.recognizeText(in:)  → OCRResult
  ├── ClipboardService.copy(text)
  └── NotificationService.showOCRComplete(text:)
```

---

## 各サービスの実装詳細

### HotkeyService
- **API**: `CGEvent.tapCreate(tap:place:options:eventsOfInterest:callback:userInfo:)`
- tap = session (`rawValue: 0`), place = tail (`rawValue: 1`), options = listenOnly (`rawValue: 1`)
- callback は literal closure のみ（static method 参照は C function pointer に変換不可）
- `CGEvent.tapEnable(tap:enable:)` で有効/無効切り替え
- RunLoopSource: `CFMachPortCreateRunLoopSource` → `CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)`
- Cleanup: tap と source を nil にすれば ARC で解放（`CGEventTapDestroy` は不存在）
- **動的キー切り替え**: `targetKeyCode`/`targetFlags` をインスタンスプロパティとして保持。コールバック内で毎回読み取る → tap 再登録なしで `updateBinding(_:)` で変更可
- Option キーの CGEventFlags: `.maskAlternate`（`.maskOption` は不存在）

### SelectionService / SelectionOverlayView
- `@MainActor` クラス
- NSWindow: `.borderless`, level `.screenSaver`
- NSView で `isFlipped = true`（座標原点を左上にする）
- `draw(_:)` メソッド（`draw(in:)` ではない）
- 座標変換: `convert(event.locationInWindow, from: nil)` で ウィンドウ座標 → ビュー座標
- Retina 対応: viewRect × `screen.backingScaleFactor` = pixelRect（CGImage クロップ用）

### ScreenCaptureService
- `CGWindowListCreateImage` は macOS 15.0 で **unavailable**（使用不可）
- `SCScreenshotManager.captureImage(in:completionHandler:)` を使用（macOS 15.2+）
- `#available(macOS 15.2, *)` で条件付き呼び出し
- `import ScreenCaptureKit` で利用可（SPM で framework 指定不要）

### OCRService
- **同期API**（`throws` のみ、`async` ではない）
- `warmUp()`: 起動時に `DispatchQueue.global()` で呼び出し、1x1 CGImage で VNRequest を実行する。Vision モデルを事前にロードし、初回OCR時の遅延（~0.6s）を排除
- `image.cgImage(forProposedRect:context:hints:)` で NSImage → CGImage
- `request.results` は既に `[VNRecognizedTextObservation]?`（キャスト不要）
- 各 observation の候補: `$0.topCandidates(1).first`（`.topCandidate` は不存在）

### NotificationService
- `truncate(_:)` で通知本文を制限: 最初の3行、最大100文字、超過時に "…" 追加
- delegate メソッド: `willPresent`（`willShow` ではない）

### SettingsService
- `UserDefaults` に JSON で永続化。キー: `"com.quickocr.settings"`
- `load() -> AppSettings`（未保存・破損時はデフォルト値を返す）/ `save(_ settings: AppSettings)`
- テスト時は injectable `UserDefaults` で検証

### TextFormatService
- `format(_ text: String) -> String`
- 単一 `\n` → スペース結合（OCR改行アーティファクト除去）
- `\n\n` 以上 → `\n\n` に正規化（段落区切り保持）

### SoundService
- `playCompletionSound()`: `NSSound.beep()` で実装
- `NSBeep()` は SPM で unavailable なため `NSSound` を使用

### LaunchAtLoginService
- `SMAppService.mainApp` の薄いラッパー
- `isEnabled`: `.enabled` で判定（`.registered` は不存在）
- `enable()` / `disable()`: `throws`。SPM デバッグビルドでは署名不足で失敗する

### ShortcutConflictChecker
- `static func conflict(for binding: KeyBinding) -> String?`
- 11件の既知システムショートカットとの静的照合（Cmd+A/C/V/X/Z/Shift+Z/S/W/R/Q/H）

### SettingsView / ShortcutRecorder
- SwiftUI `Form` ベース。NSWindow に `NSHostingView` で埋め込む
- `ShortcutRecorder`: `NSViewRepresentable` で `FocusView`（`NSView` サブクラス）を生成
- `FocusView` は Local Monitor（`addLocalMonitorForEvents`）でキーイベントを受信 → `KeyBinding` に変換。`keyDown(with:)` オーバーライドは残っているが `super` に委ねるだけ（モニタが唯一のパス）
- Esc キー(keyCode 53)でキャンセル

---

## Swift 6 / macOS 26.2 SDK での注意事項

これらは開発中に踏んだ問題で、Phase 2 実装時にも再現する可能性があります。

| 問題 | 正解 |
|------|------|
| `CGEventTapCreate` | `CGEvent.tapCreate(tap:place:options:eventsOfInterest:callback:userInfo:)` |
| `CGEventTapEnable` | `CGEvent.tapEnable(tap:enable:)` |
| `CGEventFlags.eventFlagCommand` | `.maskCommand`（同様に `.maskShift`, `.maskControl`） |
| `CGEventField.keyboardEventKeystroke` | `.keyboardEventKeycode` |
| `CGEventTapRunLoopSource` | `CFMachPortCreateRunLoopSource` |
| `CGEventTapDestroy` | 不存在。nil にすれば ARC で解放 |
| `kCFRunLoopModeCommon` | `.commonModes`（文字列キャスト不要） |
| `CGWindowListCreateImage` | macOS 15.0 で unavailable。`ScreenCaptureKit` を使用 |
| `NSView.draw(in:)` | `draw(_:)` |
| `NSRectFill` | `NSBezierPath(rect:).fill()` |
| `XCTAssertGreater` | 不存在。`XCTAssertTrue(a > b)` を使用 |
| `NSImage.cgImage(forProposalRect:)` | `cgImage(forProposedRect:context:hints:)` |
| `VNRecognizedTextObservation.topCandidate` | `topCandidates(1).first` |
| `NSApplication.TerminationReply` | `TerminateReply`、case は `.terminateNow` |
| `MenuBarExtra systemName:` | `systemImage:` |
| Package.swift `.macOS(.v15)` | swift-tools-version 6.0 が必要 |
| `@available` on stored property | 不可。型に `@available` を付けず `#available` で使用箇所を囲む |
| `@MainActor` クラス + non-isolated protocol | 該当メソッドに `nonisolated` を付加 |
| Static method as C callback | literal closure のみ可。Static 参照は変換不可 |
| `UNUserNotificationCenterDelegate` under `@MainActor` | `userNotificationCenter` を `nonisolated` で宣言 |
| `CGEventFlags.maskOption` | 不存在。`.maskAlternate` を使用 |
| `SMAppService.Status.registered` | 不存在。`.enabled` を使用 |
| `NSBeep()` | SPM で unavailable。`NSSound.beep()` を使用 |
| `final class` に `public` を付けず executable から参照 | SPM library/executable 分割では `public` が必要 |
| `CGImage(colorSpace:renderingIntent:)` | ラベルは `space:` / `intent:`。`CGColorRenderingIntent.default` は不存在 → `.perceptual` を使用 |
| `CGDataProvider(data: Data)` | `Data` は `CFData` に暗黙変換しない → `as CFData` で明示 |

---

## Entitlements

`QuickOCR.entitlements`:
```xml
<key>com.apple.security.app-sandbox</key>
<false/>
```
- app-sandbox = false は CGEventTap と ScreenCaptureKit に必要
- SPM ビルドでの署名には別途 codesign 設定が必要（リリース時対応）

---

## テスト戦略（実際）

- **OCRService**: NSImage を programmatic に生成（`lockFocus` + `NSBezierPath.fill` + `NSString.draw`）
- **ClipboardService**: `NSPasteboard.general` で直接検証、tearDown で クリア
- **NotificationService**: `truncate()` の純関数テスト（9件）
- **HotkeyService**: アクセシビリティ権限が必要なため、register の結果検証は環境依存。安全性テスト（nil/double unregister）のみ
- **ScreenCaptureKit**: 実環境依存のため自動テスト不可
- **SettingsService**: injectable `UserDefaults` で永続化のround-tripを検証（4件）
- **TextFormatService**: 純関数テスト。単一改行・複数改行・混在・边界値（8件）
- **LaunchAtLoginService**: SMAppService は実環境依存。自動テスト不可（署名必要）

---

**Document Version**: 3.0（Phase 2 拡張機能 完了時点）
