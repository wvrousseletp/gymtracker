import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class OfflineBannerWrapper extends StatefulWidget {
  final Widget child;

  const OfflineBannerWrapper({super.key, required this.child});

  @override
  State<OfflineBannerWrapper> createState() => _OfflineBannerWrapperState();
}

class _OfflineBannerWrapperState extends State<OfflineBannerWrapper> {
  late StreamSubscription<ConnectivityResult> _subscription;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    Connectivity().checkConnectivity().then(_updateStatus);
    _subscription = Connectivity().onConnectivityChanged.listen(_updateStatus);
  }

  void _updateStatus(ConnectivityResult result) {
    setState(() {
      _isOffline = result == ConnectivityResult.none;
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_isOffline)
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            child: SafeArea(
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xff1c1c1e).withOpacity(0.9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.wifi_off_rounded, color: Colors.redAccent.shade200, size: 18),
                      const SizedBox(width: 8),
                      const Text(
                        "Você está offline. Alterações serão sincronizadas depois.",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
