import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/top_toast.dart';
import '../../../auth/domain/entities/psychologist_user_entity.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class CounselorExternalApiKeyModal {
  static void show(BuildContext context, {required PsychologistUserEntity? user, required WidgetRef ref}) {
    if (user?.isVolunteer == true) {
      TopToast.show(
        context,
        title: 'Akses Dibatasi',
        message: 'Relawan Sebaya hanya melayani konseling daring non-klinis dan tidak memiliki akses integrasi jadwal offline.',
        type: ToastType.warning,
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _CounselorExternalApiKeySheet(initialUser: user),
    );
  }
}

class _CounselorExternalApiKeySheet extends ConsumerStatefulWidget {
  final PsychologistUserEntity? initialUser;

  const _CounselorExternalApiKeySheet({required this.initialUser});

  @override
  ConsumerState<_CounselorExternalApiKeySheet> createState() =>
      _CounselorExternalApiKeySheetState();
}

class _CounselorExternalApiKeySheetState
    extends ConsumerState<_CounselorExternalApiKeySheet> {
  bool _isKeyVisible = false;
  bool _isSyncing = false;

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    TopToast.show(
      context,
      title: 'Tersalin ke Clipboard 📋',
      message: '$label telah disalin ke clipboard.',
      type: ToastType.success,
    );
  }

  void _handleSync() async {
    setState(() => _isSyncing = true);
    final count = await ref.read(authStateProvider.notifier).syncExternalSchedules();
    if (!mounted) return;
    setState(() => _isSyncing = false);

    TopToast.show(
      context,
      title: 'Sinkronisasi Berhasil! 🔄',
      message: '$count slot jadwal offline dari sistem eksternal berhasil diimpor ke jadwal praktik Anda.',
      type: ToastType.success,
    );
  }

  void _confirmRegenerateKey(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.warning),
            SizedBox(width: 8),
            Text('Rotasi API Key?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'API Key lama akan langsung tidak berlaku. Sistem eksternal (SIMRS/EHR) Anda harus diperbarui dengan API Key baru agar sinkronisasi jadwal offline tetap berjalan.',
          style: TextStyle(fontSize: 12, height: 1.4, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(dialogCtx);
              ref.read(authStateProvider.notifier).generateOrRotateExternalApiKey();
              TopToast.show(
                context,
                title: 'API Key Berhasil Dirotasi! 🔑',
                message: 'API Key baru telah dibuat. Jangan lupa perbarui header sistem Anda.',
                type: ToastType.success,
              );
            },
            child: const Text('Ya, Rotasi Kunci'),
          ),
        ],
      ),
    );
  }

  void _confirmRevokeKey(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: AppColors.error),
            SizedBox(width: 8),
            Text('Cabut API Key?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Akses integrasi eksternal jadwal offline akan dimatikan sampai Anda membuat kunci baru.',
          style: TextStyle(fontSize: 12, height: 1.4, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(dialogCtx);
              ref.read(authStateProvider.notifier).revokeExternalApiKey();
              TopToast.show(
                context,
                title: 'API Key Dicabut',
                message: 'Integrasi jadwal offline eksternal telah dinonaktifkan.',
                type: ToastType.info,
              );
            },
            child: const Text('Cabut Akses'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value ?? widget.initialUser;
    final apiKey = user?.externalApiKey;
    final nip = user?.employeeNip ?? '198804122019032001';

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Modal Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.key_rounded, size: 22, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text(
                      'Integrasi API Jadwal Eksternal',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Gunakan Personal Access Token (API Key) dan NIP Pegawai Anda untuk mengambil serta menyinkronkan jadwal offline dari SIMRS, EHR, atau sistem klinik luar.',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 16),

            // Card 1: NIP Pegawai (Identifier Unik)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.badge_outlined, size: 16, color: AppColors.primary),
                          SizedBox(width: 6),
                          Text(
                            'IDENTIFIER PEGAWAI (X-EMPLOYEE-NIP)',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      InkWell(
                        onTap: () => _copyToClipboard(context, nip, 'NIP Pegawai'),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.copy_rounded, size: 12, color: AppColors.primary),
                              SizedBox(width: 4),
                              Text('Salin NIP', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    nip,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Identifier ini dikirimkan via header HTTP untuk memvalidasi kepemilikan data jadwal offline.',
                    style: TextStyle(fontSize: 10, color: AppColors.textLight),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Card 2: GitHub-Style Personal Access Token (API Key)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A), // Dark slate GitHub dev theme
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.vpn_key_rounded, size: 16, color: Color(0xFF38BDF8)),
                          SizedBox(width: 6),
                          Text(
                            'PERSONAL ACCESS TOKEN (API KEY)',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: apiKey != null ? const Color(0xFF065F46) : const Color(0xFF7F1D1D),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          apiKey != null ? 'Aktif' : 'Tidak Aktif',
                          style: TextStyle(
                            color: apiKey != null ? const Color(0xFF6EE7B7) : const Color(0xFFFCA5A5),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (apiKey == null) ...[
                    const Text(
                      'Anda belum memiliki API Key aktif. Generate kunci untuk mulai menyinkronkan jadwal offline dari klinik atau rumah sakit.',
                      style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 11, height: 1.4),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      onPressed: () {
                        ref.read(authStateProvider.notifier).generateOrRotateExternalApiKey();
                        TopToast.show(
                          context,
                          title: 'API Key Berhasil Dibuat! 🔑',
                          message: 'Kunci akses jadwal eksternal aktif.',
                          type: ToastType.success,
                        );
                      },
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('Generate API Key Baru', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ] else ...[
                    // Key Value with Mask
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _isKeyVisible
                                  ? apiKey
                                  : 'eva_pat_live_${'•' * 18}${apiKey.length >= 4 ? apiKey.substring(apiKey.length - 4) : '3a9f'}',
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                color: Color(0xFF38BDF8),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              _isKeyVisible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                              size: 18,
                              color: const Color(0xFF94A3B8),
                            ),
                            onPressed: () => setState(() => _isKeyVisible = !_isKeyVisible),
                            tooltip: _isKeyVisible ? 'Sembunyikan' : 'Tampilkan',
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 18, color: Color(0xFF38BDF8)),
                            onPressed: () => _copyToClipboard(context, apiKey, 'API Key'),
                            tooltip: 'Salin API Key',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Scopes badge (GitHub-style)
                    const Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _ScopeChip(label: 'schedules:read'),
                        _ScopeChip(label: 'offline_sync:write'),
                        _ScopeChip(label: 'counselor:nip_auth'),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Sync metadata
                    Row(
                      children: [
                        const Icon(Icons.sync_rounded, size: 14, color: Color(0xFF94A3B8)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Sinkronisasi Terakhir: ${user?.externalApiLastSyncAt != null ? "Hari ini (${user!.externalSyncCount} slot terimpor)" : "Belum ada"}',
                            style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0284C7),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: _isSyncing ? null : _handleSync,
                            icon: _isSyncing
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.sync_rounded, size: 16),
                            label: Text(
                              _isSyncing ? 'Menyinkronkan...' : 'Uji Sinkronisasi',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.restart_alt_rounded, size: 18, color: Color(0xFFCBD5E1)),
                          onPressed: () => _confirmRegenerateKey(context),
                          tooltip: 'Rotasi Token',
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFF87171)),
                          onPressed: () => _confirmRevokeKey(context),
                          tooltip: 'Cabut Kunci',
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Card 3: Integrasi & Quick Start cURL
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.terminal_rounded, size: 16, color: AppColors.primary),
                          SizedBox(width: 6),
                          Text(
                            'CUPLIKAN INTEGRASI cURL',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      InkWell(
                        onTap: () {
                          final curl = 'curl -X GET "https://api.eva.id/v1/counselor/external-schedules" \\\n'
                              '  -H "X-EVA-API-KEY: ${apiKey ?? "YOUR_API_KEY"}" \\\n'
                              '  -H "X-EMPLOYEE-NIP: $nip"';
                          _copyToClipboard(context, curl, 'Perintah cURL');
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          child: Text(
                            'Salin cURL',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'curl -X GET "https://api.eva.id/v1/counselor/external-schedules" \\\n'
                      '  -H "X-EVA-API-KEY: ${apiKey != null && apiKey.length > 14 ? "${apiKey.substring(0, 14)}..." : (apiKey ?? "YOUR_KEY")}" \\\n'
                      '  -H "X-EMPLOYEE-NIP: $nip"',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                        color: Color(0xFFE2E8F0),
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Sistem SIMRS atau kalender eksternal dapat mengirimkan data jadwal offline berformat JSON agar slot booking di Eva tidak bentrok.',
                    style: TextStyle(fontSize: 10, color: AppColors.textSecondary, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            CustomButton(
              label: 'Selesai',
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScopeChip extends StatelessWidget {
  final String label;

  const _ScopeChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'monospace',
          color: Color(0xFF38BDF8),
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
