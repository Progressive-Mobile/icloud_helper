import 'dart:convert';

import 'package:cloud_helper/cloud_error.dart';
import 'package:flutter/services.dart';

/// An implementation of [CloudHelperPlatform] that uses method channels.
class CloudHelper {
  CloudHelper._();

  static Future<CloudHelper> create(String containerId) async {
    final instance = CloudHelper._();
    await instance._initialize(containerId);

    return instance;
  }

  final _methodChannel = const MethodChannel('cloud_helper');

  Future<void> _initialize(String containerId) async {
    try {
      await _methodChannel.invokeMethod(
        'initialize',
        {
          'containerId': containerId,
        },
      );
    } catch (err) {
      throw _mapException(err as PlatformException);
    }
  }

  Future<dynamic> addRecord({
    required String id,
    required String type,
    required dynamic data,
  }) async {
    try {
      final addedData = await _methodChannel.invokeMethod(
        'addRecord',
        {
          'id': id,
          'type': type,
          'data': jsonEncode(data),
        },
      );

      return jsonDecode(addedData);
    } catch (err) {
      throw _mapException(err as PlatformException);
    }
  }

  Future<dynamic> editRecord({
    required String id,
    required dynamic data,
  }) async {
    try {
      final editedData = await _methodChannel.invokeMethod(
        'editRecord',
        {
          'id': id,
          'data': jsonEncode(data),
        },
      );
      return jsonDecode(editedData);
    } catch (err) {
      throw _mapException(err as PlatformException);
    }
  }

  Future<List<dynamic>?> getAllRecords({
    required String type,
  }) async {
    try {
      final data = await _methodChannel.invokeMethod(
        'getAllRecords',
        {
          'type': type,
        },
      ) as List<dynamic>?;

      return data?.map((e) => jsonDecode(e)).toList();
    } catch (err) {
      if (err is PlatformException && (err.message?.contains('Did not find record type: $type') ?? false)) {
        return [];
      }
      throw _mapException(err as PlatformException);
    }
  }

  Future<void> deleteRecord({
    required String id,
  }) async {
    try {
      await _methodChannel.invokeMethod(
        'deleteRecord',
        {
          'id': id,
        },
      );
    } catch (err) {
      throw _mapException(err as PlatformException);
    }
  }

  CloudError _mapException(PlatformException err) {
    if (err.message?.contains('CloudKit access was denied by user settings') ?? false) {
      return const PermissionError();
    }
    if (err.message?.contains('Quota exceeded') ?? false) {
      return const QuotaExceededError();
    }

    switch (err.code) {
      case "ARGUMENT_ERROR":
        return const ArgumentsError();
      case "INITIALIZATION_ERROR":
        return const InitializeError();
      case "EDIT_ERROR":
        if (err.message?.contains('Record not found') ?? false) {
          return const ItemNotFoundError();
        } else {
          return UnknownError(err.message ?? 'Empty error');
        }
      case "UPLOAD_ERROR":
        if (err.message?.toLowerCase().contains('record to insert already exists') ?? false) {
          return const AlreadyExists();
        } else {
          return UnknownError(err.message ?? '');
        }
      default:
        return UnknownError(err.message ?? 'Empty error');
    }
  }
}
