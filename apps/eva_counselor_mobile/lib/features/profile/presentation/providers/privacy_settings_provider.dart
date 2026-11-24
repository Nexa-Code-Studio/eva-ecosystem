import 'package:flutter_riverpod/flutter_riverpod.dart';

class PrivacySettingsState {
  final bool isBiometricEnabled;
  final bool isTwoFactorEnabled;
  final bool isPatientNameMasked;

  const PrivacySettingsState({
    this.isBiometricEnabled = true,
    this.isTwoFactorEnabled = true,
    this.isPatientNameMasked = true,
  });

  PrivacySettingsState copyWith({
    bool? isBiometricEnabled,
    bool? isTwoFactorEnabled,
    bool? isPatientNameMasked,
  }) {
    return PrivacySettingsState(
      isBiometricEnabled: isBiometricEnabled ?? this.isBiometricEnabled,
      isTwoFactorEnabled: isTwoFactorEnabled ?? this.isTwoFactorEnabled,
      isPatientNameMasked: isPatientNameMasked ?? this.isPatientNameMasked,
    );
  }

  /// Masks patient names, e.g. "Rian Pratama" -> "R*** P***", "Samsul" -> "S***"
  String maskText(String input) {
    if (!isPatientNameMasked || input.isEmpty) return input;

    final knownNames = ['Rian Pratama', 'Dinda Kirana', 'Aditya Nugraha', 'Maya Lestari', 'Samsul', 'Rian', 'Dinda', 'Aditya', 'Maya'];
    String result = input;
    for (final name in knownNames) {
      if (result.contains(name)) {
        final parts = name.split(' ');
        final masked = parts.map((p) => p.isNotEmpty ? '${p[0]}***' : p).join(' ');
        result = result.replaceAll(name, masked);
      }
    }
    return result;
  }
}

class PrivacySettingsNotifier extends StateNotifier<PrivacySettingsState> {
  PrivacySettingsNotifier() : super(const PrivacySettingsState());

  void setBiometric(bool value) {
    state = state.copyWith(isBiometricEnabled: value);
  }

  void setTwoFactor(bool value) {
    state = state.copyWith(isTwoFactorEnabled: value);
  }

  void setMaskPatientName(bool value) {
    state = state.copyWith(isPatientNameMasked: value);
  }
}

final privacySettingsProvider =
    StateNotifierProvider<PrivacySettingsNotifier, PrivacySettingsState>((ref) {
  return PrivacySettingsNotifier();
});
