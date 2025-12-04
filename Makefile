default: run

PLATFORM ?= macos
RUST_LOG ?= zrt_client_sdk=debug

# Build envs for build-dmg
CERT ?= "Not specified"
APPLE_ID ?= "Not specified"
APP_PASSWORD ?= "Not specified"
TEAM_ID ?= "Not specified"

run:
	@echo "Running Flutter app for $(PLATFORM)..."
ifeq ($(PLATFORM),linux)
	@echo "Building release rust library for linux"
	cd rust && cargo build --release && cd ..
endif
	RUST_LOG='$(RUST_LOG)' flutter run -d $(PLATFORM)

update-deps:
	@echo "Updating Rust deps"
	cd rust && git pull && cargo update && cd ..
	@echo "Regenerating Flutter_Rust bindings"
	flutter_rust_bridge_codegen generate

build-macos-app:
	@echo "Building macOS app..."
	flutter build macos --release
	mkdir -p dist
	cp -R build/macos/Build/Products/Release/Veil.app dist/

build-signed-dmg:
	rm dist/veil.dmg || true
	flutter build macos --release
	codesign --options=runtime --deep --force \
		--preserve-metadata=entitlements \
	 	--verbose \
		--sign "$(CERT)" \
		"build/macos/Build/Products/Release/Veil.app"
	codesign -dv --verbose=4 build/macos/Build/Products/Release/Veil.app
	codesign -d --entitlements :- build/macos/Build/Products/Release/Veil.app
	ditto -c -k --sequesterRsrc --keepParent "build/macos/Build/Products/Release/Veil.app" "build/macos/Build/Products/Release/Veil.zip"
	xcrun notarytool submit "build/macos/Build/Products/Release/Veil.zip" --apple-id $(APPLE_ID) --password $(APP_PASSWORD) --team-id $(TEAM_ID) --wait
	xcrun stapler staple "build/macos/Build/Products/Release/Veil.app"
	cp "macos/app_dmg.json" "build/macos/Build/Products/Release"
	appdmg "build/macos/Build/Products/Release/app_dmg.json" "dist/veil.dmg"

help:
	@echo "" 
	@echo "[Command list]"
	@echo "run PLATFORM={platform}     - runs app with specified platform, you can check available platforms with 'flutter devices' command" 
	@echo "update-deps                 - updates rust dependencies and regenerates Flutter Rust bindings"
	@echo "build-packages              - builds packages for distribution"
	@echo ""
