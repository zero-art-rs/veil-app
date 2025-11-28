import 'dart:async';
import 'package:flutter/material.dart';
import 'package:veil/managers/svces_status_listener.dart';

class NetworkStatusBanner extends StatefulWidget {
  const NetworkStatusBanner({
    super.key,
    required this.stream,
    this.showDurationWhenOnline = const Duration(milliseconds: 1400),
    this.maxWidth,
  });

  final Stream<NetworkStatus> stream;
  final Duration showDurationWhenOnline;
  final double? maxWidth;

  @override
  State<NetworkStatusBanner> createState() => _NetworkStatusBannerState();
}

class _NetworkStatusBannerState extends State<NetworkStatusBanner> {
  NetworkStatus? _status;
  StreamSubscription<NetworkStatus>? _subscription;

  @override
  void initState() {
    super.initState();

    _subscription = widget.stream.listen((s) {
      if (s == NetworkStatus.notSet || s == NetworkStatus.connected) {
        setState(() => _status = null);
        return;
      }

      setState(() => _status = s);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 8, left: 12, right: 12),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: widget.maxWidth ?? double.infinity,
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                final offsetAnimation = Tween<Offset>(
                  begin: const Offset(0, -0.2),
                  end: Offset.zero,
                ).animate(animation);
                return SlideTransition(
                  position: offsetAnimation,
                  child: FadeTransition(opacity: animation, child: child),
                );
              },
              child: _status == null
                  ? const SizedBox.shrink(key: ValueKey('empty'))
                  : _BannerSurface(status: _status!, key: ValueKey(_status)),
            ),
          ),
        ),
      ),
    );
  }
}

class _BannerSurface extends StatelessWidget {
  const _BannerSurface({super.key, required this.status});
  final NetworkStatus status;

  @override
  Widget build(BuildContext context) {
    final (text, icon, bg, fg) = switch (status) {
      NetworkStatus.servicesUnavailable => (
        'Loading...',
        Icons.wifi_tethering_off_rounded,
        Theme.of(context).colorScheme.onPrimary, // red
        Colors.white,
      ),
      NetworkStatus.disconnected => (
        'Connecting...',
        Icons.signal_wifi_off_rounded,
        Theme.of(context).colorScheme.onPrimary, // red
        Colors.white,
      ),
      NetworkStatus.notSet => throw Exception(
        'Not set status should not be shown',
      ),
      NetworkStatus.connected => throw Exception(
        'Connected status should not be shown',
      ),
    };

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        boxShadow: kElevationToShadow[2],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(color: fg, fontWeight: FontWeight.w600),
          ),
          if (status != NetworkStatus.connected) ...[
            const SizedBox(width: 8),
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(fg),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
