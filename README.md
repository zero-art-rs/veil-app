## Prerequirements
First of all, you need to install [Flutter](https://docs.flutter.dev/install) to run this project.



This project uses `Rust` <--> `Dart bridge` and `Protobuf`. So, you need to install [Rust language](https://rust-lang.org/tools/install/) and [Protobuf](https://protobuf.dev/installation/).

## 🚀 How to Run
```bash
# Download flutter project dependencies
flutter pub get
# Runs the application, PLATFORM by default is macos
make run PLATFORM={platform}

# Use it to update rust dependencies
make update 

# To list available devices/platforms:
flutter devices
```

## 🧩 Supported Platforms
* macOS
* Windows
* Linux (Ubuntu)

## 📦 Create `.deb` for Linux and `.dmg` for MacOS
Everything is already configured — just run:

```bash
# Install Fastforge to pack application
dart pub global activate fastforge

# Needed to construct .dmg
npm install -g appdmg

# Build a release package
fastforge release --name veil 
# or 
make build-packages
```

## 🛠 Development Tips (Optional)

### 🔧 Compile `.proto` files

```bash
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

### ⚙️ Rust Bridge (Flutter <--> Rust)

This project uses [`flutter_rust_bridge`](https://cjycode.com/flutter_rust_bridge/quickstart)
to generate Rust ↔ Dart bindings.

If you modify or add Rust functionality, regenerate the bindings:

```bash
# In the project root directory
flutter_rust_bridge_codegen generate
```

> ⚠️ **Avoid Rust ownership moves in bindings.**
> Dart holds references to Rust memory; after a Rust ownership move,
> those references become `NULL`, which can cause unexpected crashes.

