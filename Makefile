.PHONY: build test app dmg install run clean help

ENTITLEMENTS = QuickOCR.entitlements
APP_DIR      = dist/QuickOCRApp.app

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
# app: release ビルド → .app バンドル → ad-hoc 署名
app:
	bash scripts/build_app.sh
	codesign --force --sign - --entitlements $(ENTITLEMENTS) $(APP_DIR)

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
