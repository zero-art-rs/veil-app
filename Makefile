default: update

run: 
	RUST_LOG='zrt_client_sdk=debug' flutter run --release -d macos

update:
	cd rust && git pull && cargo update && cd .. && RUST_LOG='zrt_client_sdk=debug' flutter run -d macos

lnx:
	cd rust && git pull && cargo update && cargo build --release && cd .. && RUST_LOG='zrt_client_sdk=debug' flutter run -d linux