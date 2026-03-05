import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class VpnChannel {
  static const MethodChannel _channel = MethodChannel('vpn');
  static const EventChannel _eventChannel = EventChannel('vpn_status');

  // Cached broadcast stream — only one native listener at a time
  static Stream<String>? _cachedStream;

  /// Stream of VPN status events: "connected", "disconnected", "error:<message>"
  static Stream<String> get statusStream {
    _cachedStream ??= _eventChannel
        .receiveBroadcastStream()
        .map((event) => event.toString())
        .asBroadcastStream();
    return _cachedStream!;
  }

  /// Start VPN with the given proxy URL.
  /// The actual connection result arrives via [statusStream], not from this future.
  static Future<void> startVpn(String proxyUrl) async {
    try {
      await _channel.invokeMethod('startVpn', {'proxy': proxyUrl});
    } on PlatformException catch (e) {
      debugPrint("Native Error: ${e.message}");
      rethrow;
    }
  }

  /// Stop the VPN. Disconnection confirmation arrives via [statusStream].
  static Future<void> stopVpn() async {
    await _channel.invokeMethod('stopVpn');
  }
}
