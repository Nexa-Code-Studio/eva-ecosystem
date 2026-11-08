import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:eva_mobile/core/network/api_client.dart';
import 'package:eva_mobile/core/network/fallback_policy.dart';

void main() {
  group('FallbackPolicy', () {
    test('should return true for connection/socket error', () {
      expect(FallbackPolicy.shouldFallback(const SocketException('Failed host lookup')), isTrue);
      expect(FallbackPolicy.shouldFallback(TimeoutException('Request timed out')), isTrue);
      expect(FallbackPolicy.shouldFallback(Exception('Connection refused')), isTrue);
    });

    test('should return true for HTTP 404 Not Found and HTTP 501 Not Implemented', () {
      expect(FallbackPolicy.shouldFallback(ApiException('Not Found', statusCode: 404)), isTrue);
      expect(FallbackPolicy.shouldFallback(ApiException('Not Implemented', statusCode: 501)), isTrue);
      expect(FallbackPolicy.shouldFallback(ApiException('Connection dropped', statusCode: null)), isTrue);
    });

    test('should return false for business errors 401, 403, 422, and 500', () {
      expect(FallbackPolicy.shouldFallback(ApiException('Unauthorized', statusCode: 401)), isFalse);
      expect(FallbackPolicy.shouldFallback(ApiException('Forbidden', statusCode: 403)), isFalse);
      expect(FallbackPolicy.shouldFallback(ApiException('Unprocessable Entity', statusCode: 422)), isFalse);
      expect(FallbackPolicy.shouldFallback(ApiException('Internal Server Error', statusCode: 500)), isFalse);
    });
  });

  group('FallbackExecutor', () {
    test('should execute remote successfully without fallback when remote succeeds', () async {
      final result = await FallbackExecutor.execute<String>(
        remoteCall: () async => 'remote_ok',
        mockCall: () async => 'mock_data',
        operationName: 'testOperation',
      );
      expect(result, equals('remote_ok'));
    });

    test('should fallback to mock when remote fails with 404', () async {
      final result = await FallbackExecutor.execute<String>(
        remoteCall: () async => throw ApiException('Not found', statusCode: 404),
        mockCall: () async => 'mock_data',
        operationName: 'testOperation404',
      );
      expect(result, equals('mock_data'));
    });

    test('should rethrow original exception when remote fails with 500', () async {
      expect(
        () async => FallbackExecutor.execute<String>(
          remoteCall: () async => throw ApiException('Backend bug', statusCode: 500),
          mockCall: () async => 'mock_data',
          operationName: 'testOperation500',
        ),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 500)),
      );
    });
  });
}
