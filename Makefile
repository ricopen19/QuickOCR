.PHONY: build run clean

APP_BUNDLE = .build/QuickOCRApp.app
ENTITLEMENTS = QuickOCR.entitlements

build:
	swift build
	codesign --force --sign - --entitlements $(ENTITLEMENTS) $(APP_BUNDLE)

run: build
	open $(APP_BUNDLE)

clean:
	swift package clean
