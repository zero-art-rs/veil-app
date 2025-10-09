# How to run
```
flutter run -d <platform>

flutter devices # to see avaliable platforms 
```

# Supporting platforms
- macOS
- iOS
- Linux
- Android (not yet)
- Windows (not yet)
# Development tips (optional)

### Compile proto 
```
# Install protobuf compiler
brew install protobuf

# Activate dart tool to generate proto files
dart pub global activate protoc_plugin 21.1.2 // other versions will not compile zero_art.proto on dart

# Temporary add it to your PATH 
# Or add it your shell configuration (.zshrc, .bashrc etc.)
export PATH="$PATH:$HOME/.pub-cache/bin"

# Generate dart proto files
protoc \
  -Ilib/protos \
  --dart_out=lib/protos \
  lib/protos/*.proto \
  google/protobuf/timestamp.proto
```

### Create .deb for linux
Everything is configurated, so you should only execute the following commands: 
```
# Install fastforge
dart pub global activate fastforge

# Run this command to make a package
fastforge release --name veil
```

If you want to another package format see
[Fastforge docs](https://fastforge.dev/getting-started) 

### Rust bridge
This project uses `flutter_rust_bridge` to generate `Rust -> Dart` bindings, if you want to provide/modify rust functionallity you need to regenerate bindings, for whis purpose run: 
```
# In project directory
flutter_rust_bridge_codegen run 
```
To write `Dart`-compatible `Rust` code see [here](https://cjycode.com/flutter_rust_bridge/quickstart).

> Avoid `Rust` `ownership` operations in bindings. Dart holds reference on memory theorefore after `Rust` ownership operation this reference will be `NULL` that will surprise you.