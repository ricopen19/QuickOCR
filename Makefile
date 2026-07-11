.PHONY: build test app dmg install run clean help

ENTITLEMENTS  = QuickOCR.entitlements
APP_DIR       = dist/QuickOCRApp.app
SIGN_IDENTITY = Apple Development: auto_mato@icloud.com (QYG28ZT55K)

# ── ヘルプ ──────────────────────────────────────────
help:
	@echo ""
	@echo "  build    デバッグビルド"
	@echo "  test     テスト実行"
	@echo "  app      .app バンドル生成（release + 署名）"
	@echo "  dmg      DMG インストーラー生成"
	@echo "  install  /Applications へのインストール"
	@echo "  run      インストールして起動"
	@echo "  clean    ビルド成果物を全削除"
	@echo ""

# ── 開発 ────────────────────────────────────────────
build:
	swift build

test:
	swift test

# ── ビルド・パッケージング ──────────────────────────
# app: release ビルド → .app バンドル → Apple Development 証明書で署名
# TCC (画面収録・入力監視等) の権限をリビルドごとに保持するため、安定した署名 ID を使う
app:
	bash scripts/build_app.sh
	codesign --force --sign "$(SIGN_IDENTITY)" --entitlements $(ENTITLEMENTS) $(APP_DIR)

# dmg: .app バンドルから DMG を生成（create_dmg.sh 内で build_app.sh を実行）
dmg:
	bash scripts/create_dmg.sh

# ── インストール ────────────────────────────────────
# install: 署名済み .app を /Applications にコピー
install: app
	cp -R $(APP_DIR) /Applications/

# run: インストールして起動
run: install
	open /Applications/QuickOCRApp.app

# ── クリーンアップ ──────────────────────────────────
clean:
	swift package clean
	rm -rf dist
