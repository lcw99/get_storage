import 'dart:async';
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import '../storage_impl.dart' show GetStorage, StorageLogLevel;
import '../value.dart';

class StorageImpl {
  StorageImpl(this.fileName, [this.path]);
  html.Storage get localStorage => html.window.localStorage;

  final String? path;
  final String fileName;

  ValueStorage<Map<String, dynamic>> subject = ValueStorage<Map<String, dynamic>>(<String, dynamic>{});

  void clear() {
    localStorage.remove(fileName);
    subject.value.clear();

    subject
      ..value.clear()
      ..changeValue("", null);
  }

  Future<bool> _exists() async {
    return localStorage.containsKey(fileName);
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
    //  return _writeToStorage(subject.value);
  }

  void write(String key, dynamic value) {
    subject
      ..value[key] = value
      ..changeValue(key, value);
    //return _writeToStorage(subject.value);
  }

  // void writeInMemory(String key, dynamic value) {

  // }

  Future<void> _writeToStorage(Map<String, dynamic> data) async {
    try {
      final encoded = json.encode(subject.value);
      localStorage.update(fileName, (val) => encoded, ifAbsent: () => encoded);
    } catch (e) {
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
        final encoded = json.encode(subject.value);
        localStorage.update(fileName, (val) => encoded, ifAbsent: () => encoded);
      } else {
        GetStorage.logMessage(fileName, StorageLogLevel.warn, 'all keys non-encodable, skip flush');
      }
    }
  }

  Future<void> _readFromStorage() async {
    final dataFromLocal = localStorage.entries.firstWhereOrNull(
      (value) {
        return value.key == fileName;
      },
    );
    if (dataFromLocal != null) {
      subject.value = json.decode(dataFromLocal.value) as Map<String, dynamic>;
    } else {
      await _writeToStorage(<String, dynamic>{});
    }
  }
}

extension FirstWhereExt<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T element) test) {
    for (var element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
