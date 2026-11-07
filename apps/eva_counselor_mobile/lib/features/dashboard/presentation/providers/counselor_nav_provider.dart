import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for managing the active tab index in CounselorMainShellScreen.
/// 0: Beranda (Home Dashboard)
/// 1: Pasien (Patient List)
/// 2: Keuangan (Finances & Payouts)
/// 3: Profil (Profile & Practice Settings)
final counselorBottomNavIndexProvider = StateProvider<int>((ref) => 0);
