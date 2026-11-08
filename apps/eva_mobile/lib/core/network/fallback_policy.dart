import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'api_client.dart';

/// Policy governing whether a failed remote operation should gracefully fallback to mock data.
class FallbackPolicy {
  /// Evaluates whether an error indicates an unavailable backend or missing endpoint,
  /// qualifying it for a seamless fallback to Mock DataSource.
  ///
  /// Criteria:
  /// - TRUE for: SocketException, TimeoutException, connection refused, host lookup failures,
  ///   or HTTP 404 (Not Found) / 501 (Not Implemented).
  /// - FALSE for: HTTP 401 (Unauthorized), 403 (Forbidden), 422 (Unprocessable),
  ///   or 500 (Internal Server Error) to avoid masking actual business bugs.
  static bool shouldFallback(Object error) {
    if (error is SocketException || error is TimeoutException) {
      return true;
    }
    if (error is ApiException) {
      final code = error.statusCode;
      if (code == 404 || code == 501 || code == null) {
        return true;
      }
      return false; // Real errors (401, 403, 422, 500) must propagate
    }
    final msg = error.toString().toLowerCase();
    if (msg.contains('connection refused') ||
        msg.contains('failed host lookup') ||
        msg.contains('network is unreachable') ||
        msg.contains('failed to connect') ||
        msg.contains('timed out')) {
      return true;
    }
    return false;
  }
}

/// Helper utility for coordinating remote execution with transparent fallback to mock data.
class FallbackExecutor {
  /// Executes [remoteCall]. If an error occurs that satisfies [FallbackPolicy.shouldFallback],
  /// logs a prominent warning and returns the result of [mockCall].
  /// Otherwise, rethrows the original error.
  static Future<T> execute<T>({
    required Future<T> Function() remoteCall,
    required Future<T> Function() mockCall,
    required String operationName,
  }) async {
    try {
      return await remoteCall();
    } catch (e) {
      if (FallbackPolicy.shouldFallback(e)) {
        debugPrint('⚠️ [HYBRID-FALLBACK] $operationName gagal ($e). Beralih ke Mock DataSource.');
        return await mockCall();
      }
      rethrow;
    }
  }

  /// Executes a streaming [remoteStreamCall]. If it fails with a fallback-eligible error,
  /// seamlessly yields events from [mockStreamCall].
  static Stream<T> executeStream<T>({
    required Stream<T> Function() remoteStreamCall,
    required Stream<T> Function() mockStreamCall,
    required String operationName,
  }) async* {
    bool hasYielded = false;
    try {
      await for (final event in remoteStreamCall()) {
        hasYielded = true;
        yield event;
      }
    } catch (e) {
      if (!hasYielded && FallbackPolicy.shouldFallback(e)) {
        debugPrint('⚠️ [HYBRID-FALLBACK] Stream $operationName gagal ($e). Beralih ke Mock Stream.');
        await for (final event in mockStreamCall()) {
          yield event;
        }
      } else {
        rethrow;
      }
    }
  }
}
