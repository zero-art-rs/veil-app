default: run

PLATFORM ?= macos
RUST_LOG ?= zrt_client_sdk=debug

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

build-packages:
	@echo "Building packages"
	fastforge release --name veil

list: 
	@echo ""
	@echo "Commands list:"
	@echo ""
	@echo "run               - runs app" 
	@echo "update-deps       - updates rust dependencies and regenerates Flutter Rust bindings"
	@echo "build-packages    - builds packages for distribution"
	@echo ""
