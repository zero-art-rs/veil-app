default: update

update:
	cd rust && git pull && cargo update && cd .. && RUST_LOG='zrt_client_sdk=trace' flutter run -d macos

linux:
	cd rust && cargo build --release && cd .. && RUST_LOG='zrt_client_sdk=trace' flutter run -d linux