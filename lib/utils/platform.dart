import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class PlatformUtils {
  static bool get isLinux => defaultTargetPlatform == TargetPlatform.linux;
  static bool get isWindows => defaultTargetPlatform == TargetPlatform.windows;

  static bool get isDesktop =>
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.macOS;

  static bool get isMobile =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  static bool get isWeb => kIsWeb;

  static bool get isApple => defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS;

  static bool isWebMobileBrowser(BuildContext context) {
    return kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);
  }
}