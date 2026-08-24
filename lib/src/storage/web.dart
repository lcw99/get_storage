import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import '../storage_impl.dart' show GetStorage, StorageLogLevel;
import '../value.dart';

// Web Storage API bindings using js_interop
@JS('localStorage.getItem')
external String? _getItem(String key);

@JS('localStorage.setItem')
external void _setItem(String key, String value);

@JS('localStorage.removeItem')
external void _removeItem(String key);

class StorageImpl {
  StorageImpl(this.fileName, [this.path]);

  final String? path;
  final String fileName;

  ValueStorage<Map<String, dynamic>> subject = ValueStorage<Map<String, dynamic>>(<String, dynamic>{});

  void clear() {
    _removeItem(fileName);
    subject.value.clear();

    subject
      ..value.clear()
      ..changeValue("", null);
  }

  Future<bool> _exists() async {
    return _getItem(fileName) != null;
  }

  Future<void> flush() {
    return _writeToStorage(subject.value);
  }

  T? read<T>(String key) {
    return subject.value[key] as T?;
  }

  T getKeys<T>() {
    return subject.value.keys as T;
  }

  T getValues<T>() {
    return subject.value.values as T;
  }

  Future<void> init([Map<String, dynamic>? initialData]) async {
    subject.value = initialData ?? <String, dynamic>{};
    if (await _exists()) {
      await _readFromStorage();
    } else {
      await _writeToStorage(subject.value);
    }
    return;
  }

  void remove(String key) {
    subject
      ..value.remove(key)
      ..changeValue(key, null);
  }

  void write(String key, dynamic value) {
    subject
      ..value[key] = value
      ..changeValue(key, value);
  }

  Future<void> _writeToStorage(Map<String, dynamic> data) async {
    try {
      final encoded = json.encode(subject.value);
      _setItem(fileName, encoded);
    } catch (e) {
      // Find non-encodable keys and log them
      final badKeys = <String>[];
      for (final entry in subject.value.entries) {
        try {
          json.encode(<String, dynamic>{entry.key: entry.value});
        } catch (_) {
          badKeys.add('${entry.key}(${entry.value.runtimeType})');
        }
      }
      GetStorage.logMessage(
          fileName,
          StorageLogLevel.error,
          'flush failed: $e\n'
          'Non-encodable keys: $badKeys\n'
          'All keys: ${subject.value.keys.toList()}');
      // Remove bad keys from in-memory storage and flush sanitized map
      for (final badKey in badKeys) {
        final key = badKey.split('(').first;
        subject.value.remove(key);
        GetStorage.logMessage(fileName, StorageLogLevel.warn, 'removed corrupted key: $key');
      }
      if (subject.value.isNotEmpty) {
        _setItem(fileName, json.encode(subject.value));
      } else {
        GetStorage.logMessage(fileName, StorageLogLevel.warn, 'all keys non-encodable, skip flush');
      }
    }
  }

  Future<void> _readFromStorage() async {
    final dataFromLocal = _getItem(fileName);
    if (dataFromLocal != null) {
      try {
        subject.value = json.decode(dataFromLocal) as Map<String, dynamic>;
      } catch (e) {
        GetStorage.logMessage(fileName, StorageLogLevel.error, 'read failed: $e');
        subject.value = {};
        await _writeToStorage(<String, dynamic>{});
      }
    } else {
      await _writeToStorage(<String, dynamic>{});
    }
  }
}
