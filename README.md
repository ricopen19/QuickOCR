# QuickOCR

Macの画面上のあらゆるテキストを瞬時にキャプチャしてコピーできる、シンプルで高速なOCRツールです。

## 特徴

- 🚀 **高速・高精度**: macOS標準のVision Frameworkを使用し、日本語・英語を高精度に認識。
- 🖱️ **簡単操作**: ショートカットキー (`Cmd+Shift+O`) で範囲を選択するだけ。
- 🔒 **プライバシー重視**: すべての処理はローカルで完結。外部通信なし。
- 🛠️ **カスタマイズ**: ショートカットキー変更、自動起動、テキスト整形などの設定機能。

## 動作環境

- macOS 14.0 (Sonoma) 以降
- Apple Silicon (推奨) または Intel Mac

## インストール

### バイナリから

[Releases](https://github.com/ricopen19/QuickOCR/releases) ページから最新の `.dmg` をダウンロードしてください。（準備中）

### ソースコードからビルド

```bash
git clone https://github.com/ricopen19/QuickOCR.git
cd QuickOCR
swift build -c release
```

ビルドされたアプリは `.build/release/QuickOCRApp` に生成されます。

## 使い方

1. アプリを起動します（初回のみ画面収録の権限許可が必要です）。
2. `Cmd + Shift + O` を押して、読み取りたい範囲をドラッグします。
3. テキストが認識され、自動的にクリップボードにコピーされます。

詳しくは [ユーザーガイド](docs/USER_GUIDE.md) をご覧ください。

## ドキュメント

- [ユーザーガイド](docs/USER_GUIDE.md)
- [トラブルシューティング](docs/TROUBLESHOOTING.md)
- [リリースノート](docs/RELEASE_NOTES.md)
- [プライバシーポリシー](docs/PRIVACY_POLICY.md)

## ライセンス

このプロジェクトは MIT ライセンスの下で公開されています。詳細は [LICENSE](LICENSE) をご覧ください。

---

© 2026 QuickOCR Project
