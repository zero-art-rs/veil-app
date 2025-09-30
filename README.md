# Support
- macOS
- ios

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
