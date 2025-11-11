import 'dart:async';
import 'package:flutter/material.dart';
import 'package:veil/managers/network_status_listener.dart';

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
  Timer? _autoHide;
  StreamSubscription<NetworkStatus>? _subscription;

  @override
  void initState() {
    super.initState();

    _subscription = widget.stream.listen((s) {
      if ((s == _status) || (_status == null && s == NetworkStatus.connected)) {
        return;
      }

      _autoHide?.cancel();
      setState(() => _status = s);

      if (s == NetworkStatus.connected) {
        _autoHide = Timer(widget.showDurationWhenOnline, () {
          if (mounted) setState(() => _status = null);
        });
      }
    });
  }

  @override
  void dispose() {
    _autoHide?.cancel();
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
      NetworkStatus.connected => (
        'Connected',
        Icons.check_circle_outline,
        const Color(0xFF2BAA4A), // green
        Colors.white,
      ),
      NetworkStatus.connectedServiceUnavailable => (
        'Service unavailable',
        Icons.wifi_tethering_off_rounded,
        const Color(0xFFFFA000), // amber
        Colors.black,
      ),
      NetworkStatus.disconnected => (
        'No connection',
        Icons.signal_wifi_off_rounded,
        const Color(0xFFE53935), // red
        Colors.white,
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
