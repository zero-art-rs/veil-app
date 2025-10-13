default: update

update:
	cd rust && git pull && cargo update && cd .. && flutter run -d macos

linux:
	cd rust && cargo build --release && cd .. && flutter run -d linux