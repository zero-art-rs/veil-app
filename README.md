# zk_notion_app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
# zk-notion-app

# To compile proto 
```
# install protobuf
brew install protobuf

dart pub global activate protoc_plugin 21.1.2 // other version will not compile zero_art.proto on dart

export PATH="$PATH:$HOME/.pub-cache/bin"

protoc \
  -Ilib/protos \
  --dart_out=lib/protos \
  lib/protos/*.proto \
  google/protobuf/timestamp.proto
```
