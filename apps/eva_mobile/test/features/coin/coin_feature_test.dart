import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:eva_mobile/config/app_config.dart';
import 'package:eva_mobile/core/network/api_client.dart';
import 'package:eva_mobile/features/coin/data/datasources/mock_coin_datasource.dart';
import 'package:eva_mobile/features/coin/data/datasources/remote_coin_datasource.dart';
import 'package:eva_mobile/features/coin/data/repositories/coin_repository_impl.dart';
import 'package:eva_mobile/features/coin/domain/entities/coin_package_entity.dart';
import 'package:eva_mobile/features/coin/domain/entities/coin_topup_order_entity.dart';
import 'package:eva_mobile/features/coin/presentation/providers/coin_provider.dart';
import 'package:eva_mobile/features/coin/presentation/screens/coin_purchase_screen.dart';
import 'package:eva_mobile/features/coin/presentation/screens/qris_payment_screen.dart';
import 'package:eva_mobile/features/home/presentation/widgets/profile_dropdown_modal.dart';

final Uint8List _validPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
);

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    AppConfig.authToken = 'test-token';
    AppConfig.useMockData = true;
  });

  group('CoinPackageEntity & CoinTopupStatus tests', () {
    test('Calculates totalCoins and formattedPrice correctly', () {
      const pkg = CoinPackageEntity(
        id: 'pkg_test',
        title: 'Paket Tes',
        coins: 100,
        bonusCoins: 25,
        priceIdr: 50000,
      );
      expect(pkg.totalCoins, 125);
      expect(pkg.formattedPrice, 'Rp 50.000');
      expect(CoinTopupStatus.fromApi('pending').isActivePending, isTrue);
      expect(CoinTopupStatus.fromApi('paid').isSuccess, isTrue);
      expect(CoinTopupStatus.fromApi('review_required').isRefundOrReview, isTrue);
    });
  });

  group('ApiClient C1 envelope & RemoteCoinDataSource tests', () {
    test('Parses C1 {detail: {code, message}} error envelope', () async {
      final mockHttp = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'detail': {
              'code': 'IDEMPOTENCY_CONFLICT',
              'message': 'Payload berbeda untuk Idempotency-Key yang sama.',
            },
          }),
          409,
        );
      });

      final client = ApiClient(client: mockHttp);
      await expectLater(
        () => client.post(
          '/coins/topups',
          body: {'package_id': 'pkg-1'},
          extraHeaders: {'Idempotency-Key': 'key-1'},
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 409)
              .having((e) => e.errorCode, 'errorCode', 'IDEMPOTENCY_CONFLICT')
              .having((e) => e.message, 'message', contains('Payload berbeda')),
        ),
      );
    });

    test('RemoteCoinDataSource sends Idempotency-Key and parses C2 DTO + QR bytes', () async {
      String? capturedKey;
      final mockHttp = MockClient((request) async {
        if (request.url.path.endsWith('/coins/packages')) {
          return http.Response(
            jsonEncode([
              {
                'id': 'pkg-uuid-1',
                'code': 'FAV',
                'name': 'Paket Favorit',
                'coins': 150,
                'bonus_coins': 20,
                'price_idr': 45000,
                'description': 'Paket hemat',
                'is_popular': true,
                'is_active': true,
              }
            ]),
            200,
          );
        }
        if (request.url.path.endsWith('/coins/topups') && request.method == 'POST') {
          capturedKey = request.headers['Idempotency-Key'];
          return http.Response(
            jsonEncode({
              'id': 'topup-1',
              'order_id': 'EVA-TOPUP-001',
              'package': {'id': 'pkg-uuid-1', 'name': 'Paket Favorit', 'coins': 150, 'bonus_coins': 20},
              'amount_idr': 45000,
              'currency': 'IDR',
              'total_coins': 170,
              'payment_method': 'qris',
              'status': 'pending',
              'qr_image_url': 'https://api.sandbox.midtrans.com/v2/qris/tx/qr-code',
              'expires_at': '2026-11-25T03:00:00Z',
              'paid_at': null,
              'created_at': '2026-11-25T02:00:00Z',
              'updated_at': '2026-11-25T02:00:00Z',
            }),
            201,
          );
        }
        if (request.url.path.endsWith('/coins/topups/topup-1/qr')) {
          return http.Response.bytes(_validPng, 200);
        }
        if (request.url.path.endsWith('/users/coins')) {
          return http.Response(jsonEncode({'user_id': 'u1', 'coin_balance': 370}), 200);
        }
        if (request.url.path.endsWith('/coins/topups/topup-1/simulate-paid') && request.method == 'POST') {
          return http.Response(
            jsonEncode({
              'id': 'topup-1',
              'order_id': 'EVA-TOPUP-123',
              'package': {'id': 'pkg-uuid-1', 'name': 'Paket Favorit', 'coins': 150, 'bonus_coins': 20},
              'amount_idr': 45000,
              'currency': 'IDR',
              'total_coins': 170,
              'payment_method': 'qris',
              'status': 'paid',
              'paid_at': DateTime.now().toUtc().toIso8601String(),
              'created_at': DateTime.now().toUtc().toIso8601String(),
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            }),
            200,
          );
        }
        return http.Response('Not found', 404);
      });

      final ds = RemoteCoinDataSource(client: ApiClient(client: mockHttp));
      final repo = CoinRepositoryImpl(ds);

      final pkgs = await repo.getPackages();
      expect(pkgs.length, 1);
      expect(pkgs.first.totalCoins, 170);

      final order = await repo.createTopupOrder(packageId: 'pkg-uuid-1', idempotencyKey: 'idem-xyz');
      expect(capturedKey, 'idem-xyz');
      expect(order.status, CoinTopupStatus.pending);
      expect(order.amountIdr, 45000);

      final qrBytes = await repo.fetchTopupQrBytes('topup-1');
      expect(qrBytes, _validPng);

      final balance = await repo.getMyCoinBalance();
      expect(balance, 370);

      final simPaid = await repo.simulateTopupPayment('topup-1');
      expect(simPaid.status, CoinTopupStatus.paid);
    });
  });

  group('CoinBalanceNotifier & TopupFlowNotifier tests', () {
    test('Live mode starts at 0, syncs from server, and ignores fake local addCoins', () async {
      int serverCoins = 42;
      final mockHttp = MockClient((request) async {
        if (request.url.path.endsWith('/users/coins')) {
          return http.Response(jsonEncode({'user_id': 'u1', 'coin_balance': serverCoins}), 200);
        }
        return http.Response('{}', 200);
      });

      final repo = CoinRepositoryImpl(RemoteCoinDataSource(client: ApiClient(client: mockHttp)));
      final notifier = CoinBalanceNotifier(repository: repo, isMockMode: false);
      expect(notifier.state, 0);

      await notifier.syncFromServer();
      expect(notifier.state, 42);

      // addCoins in live mode syncs from server instead of fabricating local SharedPreferences coins
      await notifier.addCoins(999);
      expect(notifier.state, 42);
    });

    test('TopupFlowNotifier reuses Idempotency-Key across retry and updates balance when paid', () async {
      final keysSeen = <String>[];
      int serverBalance = 100;
      String currentStatus = 'pending';

      final mockHttp = MockClient((request) async {
        if (request.url.path.endsWith('/users/coins')) {
          return http.Response(jsonEncode({'user_id': 'u1', 'coin_balance': serverBalance}), 200);
        }
        if (request.url.path.endsWith('/coins/topups') && request.method == 'POST') {
          keysSeen.add(request.headers['Idempotency-Key'] ?? '');
          if (keysSeen.length == 1) {
            return http.Response(
              jsonEncode({
                'detail': {'code': 'PROVIDER_UNAVAILABLE', 'message': 'Timeout sementara'}
              }),
              503,
            );
          }
          return http.Response(
            jsonEncode({
              'id': 'ord-1',
              'order_id': 'EVA-TOPUP-1',
              'package': {'id': 'pkg-1', 'name': 'Paket Starter', 'coins': 50, 'bonus_coins': 0},
              'amount_idr': 15000,
              'currency': 'IDR',
              'total_coins': 50,
              'payment_method': 'qris',
              'status': currentStatus,
              'qr_image_url': 'https://api.sandbox.midtrans.com/qr.png',
              'expires_at': DateTime.now().toUtc().add(const Duration(minutes: 10)).toIso8601String(),
              'created_at': DateTime.now().toUtc().toIso8601String(),
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            }),
            201,
          );
        }
        if (request.url.path.endsWith('/coins/topups/ord-1/qr')) {
          return http.Response.bytes(_validPng, 200);
        }
        if (request.url.path.endsWith('/coins/topups/ord-1')) {
          return http.Response(
            jsonEncode({
              'id': 'ord-1',
              'order_id': 'EVA-TOPUP-1',
              'package': {'id': 'pkg-1', 'name': 'Paket Starter', 'coins': 50, 'bonus_coins': 0},
              'amount_idr': 15000,
              'currency': 'IDR',
              'total_coins': 50,
              'payment_method': 'qris',
              'status': currentStatus,
              'qr_image_url': 'https://api.sandbox.midtrans.com/qr.png',
              'expires_at': DateTime.now().toUtc().add(const Duration(minutes: 10)).toIso8601String(),
              'paid_at': currentStatus == 'paid' ? DateTime.now().toUtc().toIso8601String() : null,
              'created_at': DateTime.now().toUtc().toIso8601String(),
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            }),
            200,
          );
        }
        return http.Response('{}', 200);
      });

      final repo = CoinRepositoryImpl(RemoteCoinDataSource(client: ApiClient(client: mockHttp)));
      final container = ProviderContainer(
        overrides: [
          coinUseMockModeProvider.overrideWithValue(false),
          coinRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      // First attempt fails -> keeps idempotency key
      final failed = await container.read(topupFlowProvider.notifier).startTopup('pkg-1');
      expect(failed, isNull);
      expect(container.read(topupFlowProvider).errorCode, 'PROVIDER_UNAVAILABLE');

      // Retry same package -> MUST reuse the exact same Idempotency-Key
      final created = await container.read(topupFlowProvider.notifier).startTopup('pkg-1');
      expect(created, isNotNull);
      expect(keysSeen.length, 2);
      expect(keysSeen[0], keysSeen[1]);

      // Simulate settlement on server + poll checkStatus
      currentStatus = 'paid';
      serverBalance = 150;
      await container.read(topupFlowProvider.notifier).checkStatus();
      expect(container.read(topupFlowProvider).activeOrder?.status, CoinTopupStatus.paid);
      expect(container.read(coinBalanceProvider), 150);

      // Verify pending order id cleared on paid
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('pending_topup_order_id'), isNull);
    });
  });

  group('Widget Tests', () {
    testWidgets('ProfileDropdownModal displays coin balance and triggers onCoinTap', (tester) async {
      bool coinTapped = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ProfileDropdownModal(
                userName: 'Samsul Arifin',
                userEmail: 'samsul@example.com',
                coinBalance: 250,
                onProfileTap: () {},
                onEmergencyContactsTap: () {},
                onSettingsTap: () {},
                onLogoutTap: () {},
                onCoinTap: () => coinTapped = true,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('250 Koin'), findsOneWidget);
      await tester.tap(find.text('250 Koin'));
      await tester.pumpAndSettle();
      expect(coinTapped, isTrue);
    });

    testWidgets('CoinPurchaseScreen renders live packages, QRIS method, and respects release gate', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            coinUseMockModeProvider.overrideWithValue(true),
            qrisTopupEnabledProvider.overrideWithValue(true),
          ],
          child: const MaterialApp(home: CoinPurchaseScreen()),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Beli Koin EVA'), findsOneWidget);
      expect(find.text('$kMockDefaultCoinBalance Koin'), findsOneWidget);
      expect(find.text('Paket Starter'), findsOneWidget);
      expect(find.text('Paket Favorit'), findsOneWidget);
      expect(find.text('QRIS Midtrans (Instan)'), findsOneWidget);
      expect(find.text('Bayar via QRIS'), findsOneWidget);

      // Verify release gate disabled state
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            coinUseMockModeProvider.overrideWithValue(true),
            qrisTopupEnabledProvider.overrideWithValue(false),
          ],
          child: const MaterialApp(home: CoinPurchaseScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Segera Hadir'), findsOneWidget);
    });

    testWidgets('QrisPaymentScreen renders pending QR and updates to paid', (tester) async {
      final repo = CoinRepositoryImpl(MockCoinDataSource());
      final container = ProviderContainer(
        overrides: [
          coinUseMockModeProvider.overrideWithValue(true),
          coinRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      await container.read(topupFlowProvider.notifier).startTopup('pkg_popular');
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: QrisPaymentScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Pembayaran QRIS'), findsOneWidget);
      expect(find.text('Cek Status Pembayaran'), findsOneWidget);

      await container.read(topupFlowProvider.notifier).checkStatus(forceProviderRefresh: true);
      await tester.pumpAndSettle();
      expect(find.text('Pembelian Berhasil!'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    });

    testWidgets('QrisPaymentScreen floating sandbox card settles payment and hides when disabled', (tester) async {
      final repo = CoinRepositoryImpl(MockCoinDataSource());
      final containerEnabled = ProviderContainer(
        overrides: [
          coinUseMockModeProvider.overrideWithValue(true),
          sandboxSimulationProvider.overrideWithValue(true),
          coinRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(containerEnabled.dispose);

      await containerEnabled.read(topupFlowProvider.notifier).startTopup('pkg_popular');
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: containerEnabled,
          child: const MaterialApp(home: QrisPaymentScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Simulator Sandbox'), findsOneWidget);
      expect(find.text('Simulasikan Bayar'), findsOneWidget);

      await tester.tap(find.text('Simulasikan Bayar'));
      await tester.pumpAndSettle();
      expect(find.text('Pembelian Berhasil!'), findsOneWidget);
      expect(find.text('Simulasikan Bayar'), findsNothing);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      final containerDisabled = ProviderContainer(
        overrides: [
          coinUseMockModeProvider.overrideWithValue(true),
          sandboxSimulationProvider.overrideWithValue(false),
          coinRepositoryProvider.overrideWithValue(CoinRepositoryImpl(MockCoinDataSource())),
        ],
      );
      addTearDown(containerDisabled.dispose);

      await containerDisabled.read(topupFlowProvider.notifier).startTopup('pkg_popular');
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: containerDisabled,
          child: const MaterialApp(home: QrisPaymentScreen()),
        ),
      );
      await tester.pump();
      expect(find.text('Simulasikan Bayar'), findsNothing);
      containerDisabled.read(topupFlowProvider.notifier).stopPolling();
    });

    test('QRIS top-up and sandbox simulator are enabled by default in non-mock cloud builds', () {
      expect(AppConfig.enableQrisTopup, isTrue);
      expect(AppConfig.enableSandboxSimulation, isTrue);
      expect(AppConfig.isSandboxSimulationEnabled, isTrue);

      final container = ProviderContainer(
        overrides: [coinUseMockModeProvider.overrideWithValue(false)],
      );
      addTearDown(container.dispose);

      expect(container.read(qrisTopupEnabledProvider), isTrue);
      expect(container.read(sandboxSimulationProvider), isTrue);
    });
  });
}
