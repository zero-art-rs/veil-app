## Prerequirements
First of all, you need to install [Flutter](https://docs.flutter.dev/install) to run this project.

This project uses `Rust` <--> `Dart bridge` and `Protobuf`. So, you need to install [Rust language](https://rust-lang.org/tools/install/) and [Protobuf](https://protobuf.dev/installation/).

## Supported Platforms
* macOS
* Windows
* Linux (Ubuntu)

## Run app
### Mac OS and Linux

```
# PLATFORM is one of [macos, linux]

make run PLATFORM=macos
```

Under the hood, this command adds tracing logs from `zrt_client_sdk` for the debugging issues. 

### Windows 

```
zrt_client_sdk=debug flutter run -d windows
```


## Build app
### Mac OS (.app)

To build unsigned app use the following command:

```
make build-macos-app
```

the output `.app` file find in `/dist` directory.
The `unsigned app` means that you can't distribute it between other users. Their system will not allow to install it.

### Linux (.deb)

```
# Install Fastforge to pack application
dart pub global activate fastforge

export PATH="$PATH":"$HOME/.pub-cache/bin"

# Build a release package
fastforge release --name veil 
```

### Windows (.exe)

To create an `.exe` installer you should download [Inno Setup](https://jrsoftware.org/isdl.php#stable) before.

```
# Install Fastforge to pack application
dart pub global activate fastforge

# Set YOUR_USER_NAME to add fastforge to your path (temporary)
$env:PATH = "$env:PATH;C:\Users\YOUR_USER_NAME\AppData\Local\Pub\Cache\bin"

# Build a release package
fastforge release --name veil 
```

## Make commands

```bash
# Runs the application, PLATFORM by default is macos
make run PLATFORM={platform}

# Use it to update rust dependencies
make update 

# To list available devices/platforms:
flutter devices
```

## For developers

### Compile `.proto` files

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

### Rust Bridge (Flutter <--> Rust)

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

