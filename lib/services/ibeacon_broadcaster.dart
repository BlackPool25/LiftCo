import 'package:flutter/services.dart';

class IBeaconSupport {
  const IBeaconSupport({
    required this.isSupported,
    required this.bluetoothOn,
    required this.advertisingAvailable,
    this.platform,
    this.details,
  });

  final bool isSupported;
  final bool bluetoothOn;
  final bool advertisingAvailable;
  final String? platform;
  final String? details;

  factory IBeaconSupport.fromJson(Map<String, dynamic> json) {
    return IBeaconSupport(
      isSupported: json['is_supported'] as bool? ?? false,
      bluetoothOn: json['bluetooth_on'] as bool? ?? false,
      advertisingAvailable: json['advertising_available'] as bool? ?? false,
      platform: json['platform'] as String?,
      details: json['details'] as String?,
    );
  }
}

class IBeaconBroadcaster {
  static const MethodChannel _channel = MethodChannel('com.liftco.ibeacon');

  Future<IBeaconSupport> getSupport() async {
    final result = await _channel.invokeMethod<dynamic>('getSupport');
    final map = (result as Map).cast<String, dynamic>();
    return IBeaconSupport.fromJson(map);
  }

  Future<void> start({
    required String uuid,
    required int major,
    required int minor,
    int txPower = -59,
  }) async {
    await _channel.invokeMethod<void>('start', {
      'uuid': uuid,
      'major': major,
      'minor': minor,
      'tx_power': txPower,
    });
  }

  Future<void> stop() async {
    await _channel.invokeMethod<void>('stop');
  }
}
