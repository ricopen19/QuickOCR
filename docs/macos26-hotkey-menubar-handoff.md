# macOS 26 (Tahoe) 移行トラブル — 引き継ぎ書

対象環境: ユーザーの MacBook Air, macOS 26 (Darwin 25.5.0)。おそらくベータ版。
作成日: 2026-07-10（Sonnet セッション → Fable セッションへの引き継ぎ）

## 経緯サマリ

macOS 26 移行後、QuickOCR に3つの問題が発生した。

1. アプリが即座に終了する → **解決済み**（SwiftUI `MenuBarExtra` → `NSStatusItem` への置き換え。別セッションで対応済み）
2. メニューバーアイコンが表示されない → **解決済み（2026-07-11 Fable セッション）**。ControlCenter の内部登録簿破損が原因。詳細は後述
3. `Cmd+Shift+O` グローバルホットキーが効かない → **未解決**（原因は特定済み、再設計方針は決定。実装待ち）

## 根本原因（確定事項）

### アドホック署名によるTCC権限の揮発（解決済み）

`codesign --sign -`（アドホック署名）はビルドごとにバイナリのハッシュが変わる。macOS 26 の TCC はこのハッシュ（≒署名アイデンティティ）に権限を紐付けているため、リビルドのたびに画面収録・アクセシビリティ等の許可が失効していた。

**対策済み:** Apple ID（無料の Apple Development 証明書）で安定した署名に切り替えた。

- 証明書: `Apple Development: auto_mato@icloud.com (QYG28ZT55K)`
- `Makefile` に `SIGN_IDENTITY` 変数を追加し、`codesign --sign "$(SIGN_IDENTITY)"` に変更（旧: `--sign -`）
- 証明書取得の過程で WWDR 中間証明書が未インストールだったため追加インストール済み（`security find-identity -v -p codesigning` で有効化を確認済み）
- ⚠️ この証明書は無料 Apple ID 由来のため **有効期限1年**（2027/07/10 失効）。失効後は再生成が必要
- 署名変更後、TCC の古い許可エントリが残存し「許可済みなのに動かない」現象が発生 → `tccutil reset ScreenCapture/Accessibility/ListenEvent com.quickocr.app` でリセットしてから再許可することで解消

この対策により、URLスキーム経由 (`open -a QuickOCRApp "quickocr://capture"`) でのOCRキャプチャは**正常動作を確認済み**。

### Cmd+Shift+O ホットキーが効かない（未解決・原因は特定済み）

macOS 26 では、ad-hoc署名時に以下の現象が確認された:
- Carbon `RegisterEventHotKey` は登録自体は成功する（`noErr`）が、コールバックが一切発火しない
- `CGEventSource.keyState(.combinedSessionState)` は全キーで `false` を返す
- `CGEventSource.keyState(.hidSystemState)` は **修飾キー（Cmd/Shift/Option/Control）のみ検知できるが、通常キー（O, M など）は検知不可**

このため、現在の `HotkeyService.swift`（`Sources/QuickOCR/Services/HotkeyService.swift`）は `hidSystemState` ポーリング方式で実装されているが、**通常キーを検知できない設計上の欠陥がある**。動作確認の結果、実際に `Cmd+Shift+O` は反応しない。

**署名を安定させた今、CGEventTap ベースの実装に戻せば動作する可能性が高い。** ad-hoc署名時の問題は主にTCC権限の未定着だったため、Accessibility/Input Monitoring 権限が正しく許可された状態でCGEventTapを使えば、実キーイベントを受け取れるはずというのが仮説。**この仮説は未検証**（Fableセッションでの設計判断・その後の実装セッションでの検証待ち）。

### メニューバーアイコンが表示されない（解決済み・2026-07-11）

**原因: ControlCenter の内部登録簿（trackedApplications）の交差汚染。アプリコードに問題はなかった。**

- macOS 26 では SDK 26.3+ でリンクしたアプリの `NSStatusItem` は ControlCenter プロセスがホスティングする（旧 SDK アプリは自前ウィンドウなので影響なし。CleanShot X 等が無事だった理由）
- ControlCenter は `~/Library/Group Containers/group.com.apple.controlcenter/Library/Preferences/group.com.apple.controlcenter.plist` の `trackedApplications`（ネストされた binary plist）で許可状態を管理する
- この登録簿で `com.mitchellh.ghostty`（ターミナル、isAllowed=false）のエントリの `menuItemLocations` に `com.quickocr.app` と `download.kanary` が誤って紐付いており、両者が巻き添えでブロックされていた（ログ: `Moving host to blocked list`）。ターミナルから .app を起動した際に「責任プロセス＝ghostty」として誤記録されたのが原因と推定
- **修復手順（実施済み）**: plist をバックアップ（`~/Desktop/group.com.apple.controlcenter.backup-20260711-174040.plist`）→ Python で `menuItemLocations` を自己参照に正規化 → `defaults write <plistパス> trackedApplications -data <hex>` で cfprefsd 経由で書き戻し → `killall -9 ControlCenter`（SIGKILL 必須。SIGTERM だと終了時フラッシュで巻き戻る恐れ）→ アプリ再起動
- 修復後、`Starting to track host` に変わり、レイヤー25に QuickOCR のステータスウィンドウ（幅54）が出現。アプリ終了/再起動と連動することを CGWindowList で確認済み
- ⚠️ **再発防止**: 動作確認時はターミナルから直接起動せず Spotlight/Finder 経由を推奨。再発したら同じ手順で登録簿を修復する
- Kanary も同じ修復で直るはず（Kanary の再起動が必要。未確認）

### （参考）解決前の切り分け記録

QuickOCR は `NSStatusBar.system.statusItem` でアイコンを作成しており、ログ上は正常に処理が進んでいる:

```
[QuickOCR] statusItem created, visible=1
```

さらに `log stream` で確認したところ、macOS 26 では NSStatusItem が `com.apple.controlcenter.statusitems` 経由の新しい Scene ホスティングアーキテクチャに移行しており、ログ上は `Request for ... NSStatusItemView complete!` と表示され、**OS側ではシーン作成が成功しているように見える**。

切り分け結果:
- **Kanary**（別のサードパーティ製メニューバーアプリ、クリップボード管理系）も同様にメニューバーに表示されない → **QuickOCR固有のバグではなく、システムレベルの問題である可能性が高い**
- 他のメニューバーアプリ（CleanShot X, BatteryHero, Ollama）は Mac フル再起動後は正常に表示された
- `killall ControlCenter && killall SystemUIServer` では改善せず
- Macのフル再起動でも QuickOCR と Kanary だけは改善しなかった
- System Settings > コントロールセンター > メニューバー の「メニューバーに追加することを許可」一覧では QuickOCR・Kanary ともにトグルは ON になっている（システムはアプリを認識している）
- Control Center 内の「コントロールをカスタマイズ」編集画面（新macOS 26のControl Center UI）を確認したが、ここは **Appleの標準ウィジェット専用**で、サードパーティの旧来型 `NSStatusItem` はそもそも表示対象外と判明。この画面から解決する手段はない
- `com.quickocr.app` の defaults ドメインに `"NSStatusItem VisibleCC Item-0" = 1` というキーが存在することを確認したが、これが何を制御しているか、上記の表示不可問題との関連は**未検証・未確定**

QuickOCR と Kanary に共通する要因（LSUIElement、Accessibility要求、独自描画のstatusItemボタン画像など）が本当の原因かは未特定。

## 現在の動作状態（2026-07-10時点で確認済み）

| 機能 | 状態 |
|---|---|
| アプリ起動・常駐 | ○ 正常 |
| `open -a QuickOCRApp "quickocr://capture"` でOCRキャプチャ | ○ 正常動作（選択オーバーレイが出る） |
| 画面収録権限 | ○ 許可済み・持続確認済み（署名安定化後） |
| メニューバーアイコン表示 | ○ 表示される（2026-07-11 修復済み。上記「解決済み」参照） |
| `Cmd+Shift+O` グローバルホットキー | × 効かない（`hidSystemState`ポーリングの設計限界） |
| ステータスメニューからの「設定」「終了」等 | ○ アイコン表示の復旧により使用可能 |

## 変更済みファイル

- `Makefile`: `SIGN_IDENTITY` 変数追加、`codesign --sign "$(SIGN_IDENTITY)"` に変更（証明書名は環境依存 — Fableで別Macに展開する場合は要調整）
- `Sources/QuickOCR/Services/HotkeyService.swift`: Carbon → DispatchSourceTimerポーリング(`hidSystemState`) → 現状。**通常キー非検知のため実質的に機能しない。要再設計**
- `Sources/QuickOCR/App/AppDelegate.swift`:
  - `application(_:open:)` を追加（URLスキーム `quickocr://capture` / `quickocr://capture-md` 対応）— 正常動作確認済み
  - `setupStatusItem()` / `makeStatusBarImage()` を非テンプレート画像描画に変更 — 表示問題は未解決のまま
  - デバッグ用 `NSLog` / `NSSound.beep()` が随所に残存（本番化前に要除去）
- `scripts/build_app.sh`: `CFBundleURLTypes` を Info.plist に追加（URLスキーム登録）

## ホットキー再設計方針（Fable 決定・2026-07-11 → Sonnet 実装待ち）

**方針: まず Carbon `RegisterEventHotKey` を再検証し、ダメなら CGEventTap listen-only にフォールバック。`hidSystemState` ポーリングは廃止。**

- 根拠: ad-hoc 署名時代の Carbon 失敗は TCC/署名の不安定が原因だった可能性が高い。署名安定化＋メニューバー問題の原因（責任プロセス汚染）判明を踏まえると、Carbon が最小コスト（権限不要・イベント消費可）で復活する見込みがある
- 実装手順:
  1. `HotkeyService` を Carbon `RegisterEventHotKey` 実装に戻し、実機で `Cmd+Shift+O` / `Cmd+Shift+M` 発火を検証（⚠️ 検証はターミナル起動ではなく Spotlight 起動の .app で行う）
  2. Carbon で発火しない場合のみ CGEventTap（listen-only, `.cgAnnotatedSessionEventTap`）に切り替え。要 Accessibility 権限、`CFRunLoopAddSource` の第3引数は必ず `.commonModes`（プロジェクト CLAUDE.md 参照）
  3. デバッグ用 `NSLog` / `NSSound.beep()`（`AppDelegate.swift` / `HotkeyService.swift`）とポーリングコード・`prevStates` 監視コードを削除
- 完了条件: Spotlight 起動した .app で `Cmd+Shift+O` → 選択オーバーレイ表示、`Cmd+Shift+M` → Markdown モードで発火

## Fable セッションでの検討事項（残り）

1. **証明書の運用**
   - 無料 Apple ID 証明書は1年で失効する。更新フローをどうドキュメント化・自動化するか
   - 有料 Apple Developer Program（年額）への移行が必要になるタイミングの判断
