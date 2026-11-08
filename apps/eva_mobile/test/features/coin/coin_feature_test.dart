import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:eva_mobile/features/coin/domain/entities/coin_package_entity.dart';
import 'package:eva_mobile/features/coin/presentation/providers/coin_provider.dart';
import 'package:eva_mobile/features/coin/presentation/screens/coin_purchase_screen.dart';
import 'package:eva_mobile/features/home/presentation/widgets/profile_dropdown_modal.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('CoinPackageEntity tests', () {
    test('Calculates totalCoins correctly with bonus', () {
      const pkg = CoinPackageEntity(
        id: 'pkg_test',
        title: 'Paket Tes',
        coins: 100,
        bonusCoins: 25,
        priceIdr: 50000,
      );
      expect(pkg.totalCoins, 125);
      expect(pkg.formattedPrice, 'Rp 50.000');
    });

    test('Calculates formattedPrice for large amount', () {
      const pkg = CoinPackageEntity(
        id: 'pkg_large',
        title: 'Paket Besar',
        coins: 1000,
        priceIdr: 250000,
      );
      expect(pkg.totalCoins, 1000);
      expect(pkg.formattedPrice, 'Rp 250.000');
    });
  });

  group('CoinBalanceNotifier Provider tests', () {
    test('Initializes with default balance and can add/spend coins', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(coinBalanceProvider), kDefaultCoinBalance);

      // Add coins
      await container.read(coinBalanceProvider.notifier).addCoins(50);
      expect(container.read(coinBalanceProvider), kDefaultCoinBalance + 50);

      // Spend coins
      final success = await container.read(coinBalanceProvider.notifier).spendCoins(30);
      expect(success, isTrue);
      expect(container.read(coinBalanceProvider), kDefaultCoinBalance + 20);

      // Insufficient spend
      final fail = await container.read(coinBalanceProvider.notifier).spendCoins(99999);
      expect(fail, isFalse);
      expect(container.read(coinBalanceProvider), kDefaultCoinBalance + 20);
    });
  });

  group('ProfileDropdownModal Widget tests', () {
    testWidgets('Displays coin balance with purple theme and triggers onCoinTap', (tester) async {
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
                onCoinTap: () {
                  coinTapped = true;
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify user info is displayed
      expect(find.text('Samsul Arifin'), findsOneWidget);

      // Verify coin balance is shown instead of Upgrade profile
      expect(find.text('250 Koin'), findsOneWidget);
      expect(find.text('Saldo Koin'), findsOneWidget);
      expect(find.text('Beli'), findsOneWidget);
      expect(find.text('Upgrade profile'), findsNothing);

      // Tap on the coin banner
      await tester.tap(find.text('250 Koin'));
      await tester.pumpAndSettle();

      expect(coinTapped, isTrue);
    });
  });

  group('CoinPurchaseScreen Widget tests', () {
    testWidgets('Renders balance, packages, payment methods, and purchase button', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: CoinPurchaseScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check header
      expect(find.text('Beli Koin EVA'), findsOneWidget);

      // Check default balance hero card
      expect(find.text('$kDefaultCoinBalance Koin'), findsOneWidget);

      // Check packages
      expect(find.text('Paket Starter'), findsOneWidget);
      expect(find.text('Paket Favorit'), findsOneWidget);
      expect(find.text('Paket Ultimate'), findsOneWidget);

      // Check updated benefits
      expect(find.text('Bisa Berbicara Langsung dengan EVA'), findsOneWidget);
      expect(find.text('Alat Transaksi Konsultasi Psikolog'), findsOneWidget);

      // Check purchase button
      expect(find.text('Beli Sekarang'), findsOneWidget);
    });
  });
}
