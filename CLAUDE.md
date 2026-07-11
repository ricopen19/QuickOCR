# QuickOCR — Claude 用実装ルール

> 過去の実装ミスから導かれたルール。
> 新たなミスが発見されたら末尾に追加し、都度レビューする。

---

## 実行環境の判定は必須

SwiftPM で直に実行すると実行ファイルとなり `.app` バンドルにならない。
macOS の権限モデルは `.app` 単位で管理されているため、非.app環境では以下が全て破る。

- `AXIsProcessTrusted()` が正しく動かない → グローバルイベントタップの登録に静的に失敗
- `UNUserNotificationCenter.current()` が例外でクラッシュ

**ルール：** 環境判定には必ず `AppEnvironment.isAppBundle` を使う。
非.app環境での動作を必要とする場合はプロトコル + Noop で切り替える（`NotificationService` の `NoopNotificationCenter` が参照実装）。

---

## `.screenSaver` レベルウィンドウのキーボード受信

`.screenSaver` レベルのウィンドウは First Responder になりにくい。
`keyDown(with:)` オーバーライドだけでは キーイベントが届かない。

**ルール：** キー受信が必要なウィンドウには `NSEvent.addLocalMonitorForEvents` で補強する。
`keyDown` オーバーライドは念のためのフォールバックとして残すが、唯一のパスとして当てにしない。
（参照実装: `SelectionOverlayView.viewDidMoveToWindow`）

---

## `deinit` で `@MainActor` メソッドを呼び出す

`NSView` サブクラスの `deinit` は静的解析で nonisolated 扱いになる。
`@MainActor` インスタンスメソッドを直に呼ぶと `actor-isolated-call` 警告になる。

**ルール：** `deinit` 内では `MainActor.assumeIsolated { … }` で包む。
実行時には Main スレッドで動くことが保証されているため安全だが、コンパイラに明示が必要。

---

## CGEventTap の RunLoop モード

イベントタップの RunLoopSource を Main RunLoop に追加する際のモード指定に誤りが混んでくる。

**ルール：** `CFRunLoopAddSource` の第3引数は必ず `.commonModes` を使う。
文字列キャスト (`CFRunLoopMode("kCFRunLoopModeCommon" as CFString)`) は誤り。

---

## メニューバーアイコンが突然表示されなくなったら（macOS 26）

macOS 26 では `NSStatusItem` を ControlCenter がホスティングする。ターミナルから .app を起動すると
「責任プロセス＝ターミナル」として ControlCenter の登録簿に誤記録され、ターミナルがメニューバー非許可の
場合アイコンが巻き添えブロックされる（ログ: `Moving host to blocked list`）。

**ルール：** メニューバー表示の動作確認は Spotlight/Finder 経由で起動する。
再発時の修復手順は `docs/macos26-hotkey-menubar-handoff.md` の「解決済み」セクションを参照
（trackedApplications の修復 → `killall -9 ControlCenter`）。
