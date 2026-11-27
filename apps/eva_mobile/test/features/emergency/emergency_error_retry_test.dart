import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eva_mobile/features/auth/domain/entities/emergency_contact_entity.dart';
import 'package:eva_mobile/features/auth/domain/entities/user_entity.dart';
import 'package:eva_mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:eva_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:eva_mobile/features/emergency/presentation/screens/emergency_contacts_screen.dart';
import 'package:eva_mobile/features/emergency/presentation/screens/support_emergency_screen.dart';

class _FakeAuthRepository implements AuthRepository {
  bool failLoad = false;
  bool failAdd = false;
  bool failDelete = false;
  List<EmergencyContactEntity> contacts = [];

  @override
  Future<List<EmergencyContactEntity>> getEmergencyContacts() async {
    if (failLoad) throw Exception('network error');
    return List.of(contacts);
  }

  @override
  Future<EmergencyContactEntity> addEmergencyContact(
    EmergencyContactEntity contact,
  ) async {
    if (failAdd) throw Exception('save failed');
    final saved = EmergencyContactEntity(
      id: contact.id.isEmpty ? 'new-1' : contact.id,
      name: contact.name,
      relationship: contact.relationship,
      phone: contact.phone,
      isPrimary: contact.isPrimary,
    );
    contacts.add(saved);
    return saved;
  }

  @override
  Future<void> deleteEmergencyContact(String id) async {
    if (failDelete) throw Exception('delete failed');
    contacts.removeWhere((c) => c.id == id);
  }

  @override
  Future<bool> checkEmailAvailability(String email) async => true;

  @override
  Future<UserEntity?> getCurrentUser() async => null;

  @override
  Future<UserEntity> login(String email, String password) =>
      throw UnimplementedError();

  @override
  Future<void> logout() async {}

  @override
  Future<UserEntity> register(String name, String email, String password) =>
      throw UnimplementedError();
}

void main() {
  group('EmergencyContactsScreen error & retry', () {
    testWidgets('shows error state and Muat Ulang button on load failure, then recovers',
        (tester) async {
      final fakeRepo = _FakeAuthRepository()..failLoad = true;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [authRepositoryProvider.overrideWithValue(fakeRepo)],
          child: const MaterialApp(home: EmergencyContactsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Gagal memuat kontak darurat. Periksa koneksi Anda lalu coba lagi.'),
        findsOneWidget,
      );
      expect(find.text('Muat Ulang'), findsOneWidget);

      // Retry succeeds
      fakeRepo.failLoad = false;
      fakeRepo.contacts = [
        const EmergencyContactEntity(
          id: 'c-1',
          name: 'Budi Santoso',
          relationship: 'Kakak',
          phone: '081234567890',
          isPrimary: true,
        ),
      ];
      await tester.tap(find.text('Muat Ulang'));
      await tester.pumpAndSettle();

      expect(find.text('Budi Santoso'), findsOneWidget);
      expect(find.text('Muat Ulang'), findsNothing);
    });

    testWidgets('restores contact and shows error snackbar when delete fails',
        (tester) async {
      final fakeRepo = _FakeAuthRepository()
        ..failDelete = true
        ..contacts = [
          const EmergencyContactEntity(
            id: 'c-1',
            name: 'Siti Aminah',
            relationship: 'Ibu',
            phone: '081299998888',
            isPrimary: true,
          ),
        ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [authRepositoryProvider.overrideWithValue(fakeRepo)],
          child: const MaterialApp(home: EmergencyContactsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Siti Aminah'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Hapus'));
      await tester.pumpAndSettle();

      // Contact is restored and error snackbar is shown
      expect(find.text('Siti Aminah'), findsOneWidget);
      expect(
        find.text('Gagal menghapus kontak "Siti Aminah". Coba lagi nanti.'),
        findsOneWidget,
      );
    });
  });

  group('SupportEmergencyScreen error handling', () {
    testWidgets('shows failure subtitle when primary contact fails while keeping hotline button',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fakeRepo = _FakeAuthRepository()..failLoad = true;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [authRepositoryProvider.overrideWithValue(fakeRepo)],
          child: const MaterialApp(home: SupportEmergencyScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.text('Gagal memuat kontak pribadi (ketuk untuk coba lagi)'),
        findsOneWidget,
      );
      expect(find.text('WhatsApp Krisis Dinkes DKI'), findsOneWidget);
    });
  });
}
