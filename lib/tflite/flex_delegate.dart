import 'dart:async';
import 'dart:io' show Platform;

import 'dart:ffi';

import 'package:flutter/services.dart';
import 'package:tflite_flutter/src/bindings/tensorflow_lite_bindings_generated.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

/// Wraps the native Flex delegate exposed from the Android side.
class FlexDelegate implements Delegate {
  FlexDelegate._(this._handle);

  static const MethodChannel _channel = MethodChannel('flex_delegate');

  final Pointer<TfLiteDelegate> _handle;
  bool _deleted = false;

  /// Creates a Flex delegate via the Android host. Throws on unsupported platforms.
  static Future<FlexDelegate> create() async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('Flex delegate is only available on Android.');
    }
    final handle = await _channel.invokeMethod<int>('create');
    if (handle == null || handle == 0) {
      throw StateError('Failed to obtain Flex delegate handle.');
    }
    return FlexDelegate._(Pointer.fromAddress(handle));
  }

  @override
  Pointer<TfLiteDelegate> get base => _handle;

  @override
  Future<void> delete() async {
    if (_deleted) return;
    _deleted = true;
    if (Platform.isAndroid) {
      await _channel.invokeMethod('delete', _handle.address);
    }
  }
}
