## 🚀 How to Run

```bash
# On macOS && iOS
flutter run -d <platform>
-----------
# On linux
cd rust && cargo build --release && cd .. && flutter run -d linux
-----------
# To list available devices/platforms:
flutter devices
```

## 🧩 Supported Platforms

* macOS
* iOS
* Linux (Ubuntu)

## 🛠 Development Tips (Optional)

### 🔧 Compile `.proto` Files

```bash
# Install the protobuf compiler
brew install protobuf

# Activate Dart protoc plugin (⚠️ version 21.1.2 required for zero_art.proto)
dart pub global activate protoc_plugin 21.1.2

# Add it temporarily to your PATH (or permanently to .zshrc / .bashrc)
export PATH="$PATH:$HOME/.pub-cache/bin"

# Generate Dart proto files
protoc \
  -Ilib/protos \
  --dart_out=lib/protos \
  lib/protos/*.proto \
  google/protobuf/timestamp.proto
```

### 📦 Create `.deb` Package for Linux

Everything is already configured — just run:

```bash
# Install Fastforge
dart pub global activate fastforge

# Build a release package
fastforge release --name veil
```

If you want another package format, see the
👉 [Fastforge Documentation](https://fastforge.dev/getting-started)

### ⚙️ Rust Bridge (Flutter ↔ Rust)

This project uses [`flutter_rust_bridge`](https://cjycode.com/flutter_rust_bridge/quickstart)
to generate Rust ↔ Dart bindings.

If you modify or add Rust functionality, regenerate the bindings:

```bash
# In the project root directory
flutter_rust_bridge_codegen run
```

> ⚠️ **Avoid Rust ownership moves in bindings.**
> Dart holds references to Rust memory; after a Rust ownership move,
> those references become `NULL`, which can cause unexpected crashes.

