import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/widgets/top_toast.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../widgets/counselor_duration_buffer_modal.dart';
import '../widgets/counselor_working_hours_modal.dart';

class CounselorScheduleSettingsScreen extends ConsumerStatefulWidget {
  const CounselorScheduleSettingsScreen({super.key});

  @override
  ConsumerState<CounselorScheduleSettingsScreen> createState() =>
      _CounselorScheduleSettingsScreenState();
}

class _CounselorScheduleSettingsScreenState
    extends ConsumerState<CounselorScheduleSettingsScreen> {
  final List<String> _allDays = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
  late Set<String> _onlineDays;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late int _sessionDuration;
  late int _bufferTime;
  late bool _isVacationMode;

  late bool _isOnlineEnabled;
  late bool _isOfflineEnabled;

  // Offline practice controllers
  late TextEditingController _placeController;
  late TextEditingController _addressController;
  late TextEditingController _cityController;
  late TextEditingController _notesController;
  late Set<String> _offlineDays;
  late String _offlineStartTime;
  late String _offlineEndTime;

  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _onlineDays = {'Sen', 'Sel', 'Rab', 'Kam', 'Jum'};
    _startTime = const TimeOfDay(hour: 9, minute: 0);
    _endTime = const TimeOfDay(hour: 17, minute: 0);
    _sessionDuration = 50;
    _bufferTime = 15;
    _isVacationMode = false;
    _isOnlineEnabled = true;
    _isOfflineEnabled = false;

    _placeController = TextEditingController();
    _addressController = TextEditingController();
    _cityController = TextEditingController();
    _notesController = TextEditingController();
    _offlineDays = {'Sel', 'Kam', 'Sab'};
    _offlineStartTime = '10:00';
    _offlineEndTime = '16:00';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      final user = ref.read(authStateProvider).value;
      if (user != null) {
        _isOnlineEnabled = user.isOnlinePracticeEnabled;
        _isOfflineEnabled = user.isVolunteer ? false : user.isOfflinePracticeEnabled;
        _sessionDuration = user.sessionDurationMinutes;

        _placeController.text = user.offlinePlaceName ??
            (user.isPartner
                ? 'RS Mitra Sehati - Unit Poliklinik Jiwa'
                : 'Biro Konsultasi Psikologi Mandiri Anindya');
        _addressController.text = user.offlineAddress ??
            (user.isPartner
                ? 'Jl. Gatot Subroto No. 128, Gedung Poliklinik Lt. 3'
                : 'Jl. Menteng Raya No. 42, RT 02/RW 03');
        _cityController.text = user.offlineCity ?? 'Jakarta Pusat';
        _notesController.text = user.offlineNotes ?? 'Lantai 2, Ruang Melati 1';
        _offlineDays = Set<String>.from(user.offlineScheduleDays);
        _offlineStartTime = user.offlineStartTime;
        _offlineEndTime = user.offlineEndTime;
      }
      _isInitialized = true;
    }
  }

  @override
  void dispose() {
    _placeController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String get _onlineHoursDisplay {
    final sH = _startTime.hour.toString().padLeft(2, '0');
    final sM = _startTime.minute.toString().padLeft(2, '0');
    final eH = _endTime.hour.toString().padLeft(2, '0');
    final eM = _endTime.minute.toString().padLeft(2, '0');
    return '$sH:$sM - $eH:$eM WIB';
  }

  void _handleSave() {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    if (!user.isVolunteer) {
      if (!_isOnlineEnabled && !_isOfflineEnabled) {
        TopToast.show(
          context,
          title: 'Mode Belum Dipilih',
          message: 'Pilih minimal salah satu mode (Online atau Offline).',
          type: ToastType.warning,
        );
        return;
      }

      ref.read(authStateProvider.notifier).updatePracticeModes(
            isOnline: _isOnlineEnabled,
            isOffline: _isOfflineEnabled,
          );

      if (_isOfflineEnabled && !user.isPartner) {
        ref.read(authStateProvider.notifier).updateOfflinePracticeAddress(
              placeName: _placeController.text.trim().isEmpty
                  ? 'Biro Psikologi Mandiri'
                  : _placeController.text.trim(),
              address: _addressController.text.trim().isEmpty
                  ? 'Jl. Menteng Raya No. 42'
                  : _addressController.text.trim(),
              city: _cityController.text.trim().isEmpty
                  ? 'Jakarta'
                  : _cityController.text.trim(),
              notes: _notesController.text.trim().isEmpty
                  ? null
                  : _notesController.text.trim(),
            );

        ref.read(authStateProvider.notifier).updateOfflineSchedule(
              days: _offlineDays.toList(),
              startTime: _offlineStartTime,
              endTime: _offlineEndTime,
            );
      }
    }

    ref.read(authStateProvider.notifier).updateSessionSettings(
          sessionDurationMinutes: _sessionDuration,
          coinsPerSession: user.coinsPerSession,
        );

    TopToast.show(
      context,
      title: 'Pengaturan Jadwal Tersimpan! 📅',
      message: 'Jadwal dan ketersediaan praktik Anda telah diperbarui.',
      type: ToastType.success,
    );

    Navigator.pop(context);
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 15, color: AppColors.primary),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    final isVolunteer = user?.isVolunteer == true;
    final isPartner = user?.isPartner == true;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isVolunteer ? 'Hari & Jam Praktik Online' : 'Jadwal & Lokasi Praktik',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Mode Konseling
              if (isVolunteer) ...[
                // Clean info card for peer volunteers
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFECEFF8)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.volunteer_activism_rounded, color: AppColors.primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Mode Relawan Teman Sebaya',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Sebagai relawan sebaya, layanan konsultasi difokuskan khusus telekonseling daring (video call & chat) non-klinis untuk curhat sehat.',
                              style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ] else ...[
                _buildSectionTitle('Pilih Mode Layanan Konseling', Icons.tune_rounded),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFECEFF8)),
                  ),
                  child: Column(
                    children: [
                      // Mode Online
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _isOnlineEnabled ? AppColors.primaryContainer : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.videocam_rounded,
                              color: _isOnlineEnabled ? AppColors.primary : AppColors.textSecondary,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Telekonseling Online',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Sesi tatap maya video call & chat via aplikasi Eva',
                                  style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          Switch.adaptive(
                            value: _isOnlineEnabled,
                            activeTrackColor: AppColors.primary,
                            onChanged: (val) {
                              if (!val && !_isOfflineEnabled) {
                                TopToast.show(
                                  context,
                                  title: 'Minimal 1 Mode Aktif',
                                  message: 'Pilih minimal salah satu mode (Online atau Offline).',
                                  type: ToastType.warning,
                                );
                                return;
                              }
                              setState(() => _isOnlineEnabled = val);
                            },
                          ),
                        ],
                      ),
                      const Divider(height: 20, color: Color(0xFFF0F2F8)),

                      // Mode Offline (Opsional)
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _isOfflineEnabled ? AppColors.primaryContainer : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.place_rounded,
                              color: _isOfflineEnabled ? AppColors.primary : AppColors.textSecondary,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Flexible(
                                      child: Text(
                                        'Praktik Tatap Muka',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryContainer,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'Opsional',
                                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.primary),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isPartner
                                      ? 'Alamat diatur oleh ${user?.partnerName ?? "Mitra"} di Web Portal'
                                      : 'Sesi tatap muka di klinik / tempat praktik mandiri Anda',
                                  style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          if (isPartner) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Web Mitra',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                              ),
                            ),
                          ] else ...[
                            Switch.adaptive(
                              value: _isOfflineEnabled,
                              activeTrackColor: AppColors.primary,
                              onChanged: (val) {
                                if (!val && !_isOnlineEnabled) {
                                  TopToast.show(
                                    context,
                                    title: 'Minimal 1 Mode Aktif',
                                    message: 'Pilih minimal salah satu mode (Online atau Offline).',
                                    type: ToastType.warning,
                                  );
                                  return;
                                }
                                setState(() => _isOfflineEnabled = val);
                              },
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 2. Jadwal Hari & Jam Online
              if (_isOnlineEnabled) ...[
                _buildSectionTitle('Hari & Jam Praktik Online', Icons.calendar_month_rounded),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFECEFF8)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Hari Praktik Daring Aktif:',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _allDays.map((day) {
                          final isSelected = _onlineDays.contains(day);
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  if (_onlineDays.length > 1) _onlineDays.remove(day);
                                } else {
                                  _onlineDays.add(day);
                                }
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.primary : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Text(
                                day,
                                style: TextStyle(
                                  color: isSelected ? Colors.white : AppColors.textPrimary,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                  fontSize: 11.5,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const Divider(height: 24, color: Color(0xFFF0F2F8)),

                      // Jam Operasional
                      InkWell(
                        onTap: () => CounselorWorkingHoursModal.show(
                          context: context,
                          initialStart: _startTime,
                          initialEnd: _endTime,
                          onSave: (s, e) => setState(() {
                            _startTime = s;
                            _endTime = e;
                          }),
                        ),
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.access_time_rounded, size: 16, color: AppColors.primary),
                                  SizedBox(width: 8),
                                  Text(
                                    'Jam Operasional Online',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textPrimary),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryContainer,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      _onlineHoursDisplay,
                                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 11),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(Icons.edit_outlined, size: 14, color: AppColors.primary),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Durasi & Buffer
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => CounselorDurationBufferModal.show(
                                context: context,
                                initialDuration: _sessionDuration,
                                initialBuffer: _bufferTime,
                                onSave: (d, b) => setState(() {
                                  _sessionDuration = d;
                                  _bufferTime = b;
                                }),
                              ),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Durasi Sesi', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                                        const SizedBox(height: 2),
                                        Text('$_sessionDuration Menit', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                                      ],
                                    ),
                                    const Icon(Icons.tune_rounded, size: 14, color: AppColors.primary),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: InkWell(
                              onTap: () => CounselorDurationBufferModal.show(
                                context: context,
                                initialDuration: _sessionDuration,
                                initialBuffer: _bufferTime,
                                onSave: (d, b) => setState(() {
                                  _sessionDuration = d;
                                  _bufferTime = b;
                                }),
                              ),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Jeda Buffer', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                                        const SizedBox(height: 2),
                                        Text('$_bufferTime Menit', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                                      ],
                                    ),
                                    const Icon(Icons.tune_rounded, size: 14, color: AppColors.primary),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 3. Praktik Tatap Muka (Offline)
              if (_isOfflineEnabled && !isVolunteer) ...[
                _buildSectionTitle('Alamat & Lokasi Praktik Offline', Icons.location_on_rounded),
                if (isPartner) ...[
                  // Read-only info from partner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFECEFF8)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.primaryContainer,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Dikelola oleh ${user?.partnerName ?? "Mitra"} via Web',
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          user?.offlinePlaceName ?? 'RS Mitra Sehati - Unit Poliklinik Jiwa',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${user?.offlineAddress ?? "Jl. Gatot Subroto No. 128, Lt. 3"}, ${user?.offlineCity ?? "Jakarta Selatan"}',
                          style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary, height: 1.3),
                        ),
                        if (user?.offlineNotes != null && user!.offlineNotes!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Catatan: ${user.offlineNotes}',
                            style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.textSecondary),
                          ),
                        ],
                      ],
                    ),
                  ),
                ] else ...[
                  // Editable form for independent psychologist
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFECEFF8)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CustomTextField(
                          label: 'Nama Tempat / Fasilitas Praktik',
                          hint: 'mis. Biro Psikologi Mandiri Anindya',
                          controller: _placeController,
                          prefixIcon: Icons.business_rounded,
                        ),
                        const SizedBox(height: 12),
                        CustomTextField(
                          label: 'Alamat Lengkap Praktik',
                          hint: 'Jalan, nomor bangunan, RT/RW, kelurahan/kecamatan',
                          controller: _addressController,
                          maxLines: 2,
                          prefixIcon: Icons.map_rounded,
                        ),
                        const SizedBox(height: 12),
                        CustomTextField(
                          label: 'Kota / Wilayah',
                          hint: 'mis. Jakarta Pusat',
                          controller: _cityController,
                          prefixIcon: Icons.location_city_rounded,
                        ),
                        const SizedBox(height: 12),
                        CustomTextField(
                          label: 'Petunjuk Ruang / Catatan Kedatangan (Opsional)',
                          hint: 'mis. Lantai 2, Ruang Melati. Laporkan ke resepsionis.',
                          controller: _notesController,
                          maxLines: 2,
                          prefixIcon: Icons.meeting_room_outlined,
                        ),
                        const Divider(height: 24, color: Color(0xFFF0F2F8)),

                        // Hari & Jam Offline
                        const Text(
                          'Hari Praktik Offline Aktif:',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _allDays.map((d) {
                            final isSelected = _offlineDays.contains(d);
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  if (isSelected) {
                                    if (_offlineDays.length > 1) _offlineDays.remove(d);
                                  } else {
                                    _offlineDays.add(d);
                                  }
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSelected ? AppColors.primary : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Text(
                                  d,
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : AppColors.textPrimary,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12),

                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () async {
                                  final parts = _offlineStartTime.split(':');
                                  final initial = TimeOfDay(
                                    hour: int.tryParse(parts[0]) ?? 10,
                                    minute: parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0,
                                  );
                                  final picked = await showTimePicker(context: context, initialTime: initial);
                                  if (picked != null) {
                                    setState(() {
                                      _offlineStartTime = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                                    });
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Mulai Offline', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                                      const SizedBox(height: 2),
                                      Text('$_offlineStartTime WIB', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: InkWell(
                                onTap: () async {
                                  final parts = _offlineEndTime.split(':');
                                  final initial = TimeOfDay(
                                    hour: int.tryParse(parts[0]) ?? 16,
                                    minute: parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0,
                                  );
                                  final picked = await showTimePicker(context: context, initialTime: initial);
                                  if (picked != null) {
                                    setState(() {
                                      _offlineEndTime = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                                    });
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Selesai Offline', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                                      const SizedBox(height: 2),
                                      Text('$_offlineEndTime WIB', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
              ],

              // 4. Mode Libur Sementara
              _buildSectionTitle('Ketersediaan Layanan', Icons.beach_access_rounded),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFECEFF8)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _isVacationMode ? const Color(0xFFFFF7ED) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.pause_circle_outline_rounded,
                        color: _isVacationMode ? AppColors.warning : AppColors.textSecondary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mode Libur Sementara (Cuti)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppColors.textPrimary),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Tutup sementara pemesanan slot jadwal baru tanpa mengubah jadwal rutin',
                            style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Switch.adaptive(
                      value: _isVacationMode,
                      activeTrackColor: AppColors.warning,
                      onChanged: (val) => setState(() => _isVacationMode = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 5. Tombol Simpan
              CustomButton(
                label: 'Simpan Perubahan Jadwal',
                onPressed: _handleSave,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
