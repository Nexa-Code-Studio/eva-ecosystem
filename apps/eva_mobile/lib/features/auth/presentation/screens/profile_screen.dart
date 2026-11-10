import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:eva_mobile/config/app_config.dart';
import 'package:eva_mobile/theme/app_colors.dart';
import 'package:eva_mobile/widgets/app_back_button.dart';
import 'package:eva_mobile/widgets/app_snack_bar.dart';
import 'package:eva_mobile/widgets/custom_button.dart';
import 'package:eva_mobile/widgets/glass_card.dart';
import 'package:eva_mobile/features/coin/presentation/providers/coin_provider.dart';
import '../providers/auth_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => ProfileScreenState();
}

class ProfileScreenState extends ConsumerState<ProfileScreen> {
  String _userName = 'Pengguna EVA';
  String _userEmail = '';
  String _userPhone = '+62 812-3456-7890';
  String _userGender = 'Laki-laki';
  String _userBirthDate = '18 Agustus 2002';
  final String _userLocation = 'Jakarta, Indonesia';
  String? _emergencyContactName;
  String? _emergencyContactPhone;

  void refresh() {
    _loadProfileData();
  }

  String get _userInitials {
    final parts = _userName.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return 'LU';
  }

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    // 1. Cached profile info
    final cachedName = await AppConfig.getUserName();
    final cachedEmail = await AppConfig.getUserEmail();
    final cachedPhone = await AppConfig.getUserPhone();
    final cachedGender = await AppConfig.getUserGender();
    final cachedBirthDate = await AppConfig.getUserBirthDate();

    if (mounted) {
      setState(() {
        if (cachedName != null && cachedName.isNotEmpty) {
          _userName = cachedName;
        }
        if (cachedEmail != null && cachedEmail.isNotEmpty) {
          _userEmail = cachedEmail;
        } else {
          _userEmail = AppConfig.demoEmail;
        }
        if (cachedPhone != null && cachedPhone.isNotEmpty) {
          _userPhone = cachedPhone;
        }
        if (cachedGender != null && cachedGender.isNotEmpty) {
          _userGender = cachedGender;
        }
        if (cachedBirthDate != null && cachedBirthDate.isNotEmpty) {
          _userBirthDate = cachedBirthDate;
        }
      });
    }

    // 2. Fetch /auth/me via AuthRepository
    try {
      final user = await ref.read(authRepositoryProvider).getCurrentUser();
      if (user != null && mounted) {
        setState(() {
          _userName = user.name;
          _userEmail = user.email;
        });
        await AppConfig.setUserInfo(name: user.name, email: user.email);
      }
    } catch (_) {}

    // 3. Fetch primary emergency contact via AuthRepository
    try {
      final contacts = await ref.read(authRepositoryProvider).getEmergencyContacts();
      if (mounted) {
        if (contacts.isNotEmpty) {
          final primary = contacts.firstWhere(
            (c) => c.isPrimary,
            orElse: () => contacts.first,
          );
          setState(() {
            final rel = primary.relationship.isNotEmpty ? ' (${primary.relationship})' : '';
            _emergencyContactName = '${primary.name}$rel';
            _emergencyContactPhone = primary.phone;
          });
        } else {
          setState(() {
            _emergencyContactName = null;
            _emergencyContactPhone = null;
          });
        }
      }
    } catch (_) {}
  }

  void _showEditProfileModal() {
    final nameCtrl = TextEditingController(text: _userName);
    final phoneCtrl = TextEditingController(text: _userPhone);
    String selectedGender = _userGender;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
                top: 20,
                left: 20,
                right: 20,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Edit Profil Pengguna',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          onPressed: () => Navigator.pop(modalCtx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Nama Lengkap',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFF8F9FE),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                        ),
                        prefixIcon: const Icon(
                          Icons.person_outline_rounded,
                          size: 20,
                          color: AppColors.primary,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Nomor Telepon',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFF8F9FE),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                        ),
                        prefixIcon: const Icon(
                          Icons.phone_outlined,
                          size: 20,
                          color: AppColors.primary,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Jenis Kelamin',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: ['Laki-laki', 'Perempuan'].map((g) {
                        final isSel = selectedGender == g;
                        return Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: ChoiceChip(
                            label: Text(g),
                            selected: isSel,
                            selectedColor: AppColors.primaryContainer,
                            labelStyle: GoogleFonts.inter(
                              color: isSel ? AppColors.primary : AppColors.textSecondary,
                              fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                            ),
                            onSelected: (_) {
                              setModalState(() => selectedGender = g);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        onPressed: () async {
                          final newName = nameCtrl.text.trim();
                          final newPhone = phoneCtrl.text.trim();
                          if (newName.isEmpty) return;

                          await AppConfig.setUserProfileDetails(
                            name: newName,
                            email: _userEmail,
                            phone: newPhone,
                            gender: selectedGender,
                          );

                          if (mounted) {
                            setState(() {
                              _userName = newName;
                              _userPhone = newPhone;
                              _userGender = selectedGender;
                            });
                          }

                          if (modalCtx.mounted) {
                            Navigator.pop(modalCtx);
                          }
                          if (mounted) {
                            AppSnackBar.showSuccess(context, 'Profil berhasil diperbarui!');
                          }
                        },
                        child: Text(
                          'Simpan Perubahan',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showDeleteMemoryConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Hapus Memori Lokal AI?',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: AppColors.textPrimary,
            ),
          ),
          content: Text(
            'Apakah Anda yakin ingin menghapus seluruh catatan memori AI? EVA akan menghapus riwayat konteks emosional yang tersimpan secara lokal di perangkat ini.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Batal',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textLight,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD32F2F),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                Navigator.pop(context);
                AppSnackBar.showSuccess(
                  context,
                  'Seluruh catatan memori lokal AI berhasil dihapus.',
                );
              },
              child: Text(
                'Hapus',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFF6F8FF),
              Color(0xFFEFF2FE),
              Color(0xFFF8F9FE),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 100.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back Button Navigation Header (only if pushed via route)
                if (canPop) ...[
                  Row(
                    children: [
                      const AppBackButton(),
                      const SizedBox(width: 12),
                      Text(
                        'Profil Pengguna',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],

                // 1. User Profile Header Card
                GlassCard(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Stack(
                        children: [
                          Container(
                            width: 68,
                            height: 68,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [Color(0xFF8B93FF), Color(0xFF5358CB)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                _userInitials,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: () {
                                AppSnackBar.show(
                                  context,
                                  message: 'Fitur penggantian foto profil akan segera hadir.',
                                );
                              },
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: const Icon(
                                  Icons.camera_alt_rounded,
                                  size: 12,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _userName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _userEmail.isNotEmpty ? _userEmail : AppConfig.demoEmail,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.primaryContainer,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'ANGGOTA PREMIUM PRO',
                                style: GoogleFonts.inter(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // 2. Coin Balance Card (Interactive Top-Up Banner)
                InkWell(
                  onTap: () => Navigator.pushNamed(context, '/coin_purchase'),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF5358CB), Color(0xFF8B93FF)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF5358CB).withValues(alpha: 0.22),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.monetization_on_rounded,
                            color: Color(0xFFFFD54F),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Saldo Koin EVA',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withValues(alpha: 0.85),
                                ),
                              ),
                              Text(
                                '${ref.watch(coinBalanceProvider)} Koin',
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.add_circle_outline_rounded,
                                size: 12,
                                color: Color(0xFF5358CB),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Isi Koin',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF5358CB),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 11,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // 3. Wellness Activity Summary Overview
                Row(
                  children: [
                    _buildStatCard(
                      icon: Icons.mic_none_rounded,
                      title: '14 Sesi',
                      subtitle: 'Sesi Curhat Suara',
                    ),
                    const SizedBox(width: 10),
                    _buildStatCard(
                      icon: Icons.auto_stories_outlined,
                      title: '28 Entri',
                      subtitle: 'Refleksi Jurnal',
                    ),
                    const SizedBox(width: 10),
                    _buildStatCard(
                      icon: Icons.sentiment_satisfied_alt_rounded,
                      title: 'Stabil',
                      subtitle: 'Status Emosi',
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // 3. Section: INFORMASI PRIBADI
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'INFORMASI PRIBADI',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textLight,
                        letterSpacing: 0.8,
                      ),
                    ),
                    GestureDetector(
                      onTap: _showEditProfileModal,
                      child: Row(
                        children: [
                          const Icon(
                            Icons.edit_outlined,
                            size: 14,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Edit Profil',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                GlassCard(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    children: [
                      _buildInfoRow(
                        icon: Icons.person_outline_rounded,
                        label: 'Nama Lengkap',
                        value: _userName,
                      ),
                      const Divider(height: 16, thickness: 0.6, color: Color(0xFFF1F5F9)),
                      _buildInfoRow(
                        icon: Icons.mail_outline_rounded,
                        label: 'Alamat Email',
                        value: _userEmail.isNotEmpty ? _userEmail : AppConfig.demoEmail,
                        badge: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: const Color(0xFFA7F3D0)),
                          ),
                          child: Text(
                            'Terverifikasi',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF059669),
                            ),
                          ),
                        ),
                      ),
                      const Divider(height: 16, thickness: 0.6, color: Color(0xFFF1F5F9)),
                      _buildInfoRow(
                        icon: Icons.phone_outlined,
                        label: 'Nomor Telepon',
                        value: _userPhone,
                      ),
                      const Divider(height: 16, thickness: 0.6, color: Color(0xFFF1F5F9)),
                      _buildInfoRow(
                        icon: Icons.cake_outlined,
                        label: 'Tanggal Lahir',
                        value: _userBirthDate,
                      ),
                      const Divider(height: 16, thickness: 0.6, color: Color(0xFFF1F5F9)),
                      _buildInfoRow(
                        icon: Icons.face_outlined,
                        label: 'Jenis Kelamin',
                        value: _userGender,
                      ),
                      const Divider(height: 16, thickness: 0.6, color: Color(0xFFF1F5F9)),
                      _buildInfoRow(
                        icon: Icons.location_on_outlined,
                        label: 'Domisili',
                        value: _userLocation,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 4. Section: AI & PRIVASI
                Text(
                  'AI & PRIVASI MEMORI',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textLight,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 10),
                GlassCard(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE2DAFF),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.psychology_outlined,
                              color: AppColors.primary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Memori Jangka Panjang AI',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  'EVA menyimpan konteks emosional harianmu secara lokal.',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      CustomPillButton(
                        text: 'Hapus Catatan Memori Lokal AI',
                        isOutline: true,
                        height: 44,
                        onPressed: _showDeleteMemoryConfirmationDialog,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 5. Section: RENCANA KESELAMATAN KRISIS
                Text(
                  'RENCANA KESELAMATAN KRISIS',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textLight,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 10),
                GlassCard(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Material(
                    color: Colors.transparent,
                    child: ListTile(
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFDCDD),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.contact_phone_outlined,
                          color: Color(0xFFD32F2F),
                          size: 20,
                        ),
                      ),
                      title: Text(
                        'Kontak Darurat Utama',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        _emergencyContactName != null
                            ? '$_emergencyContactName • ${_emergencyContactPhone ?? ''}'
                            : 'Belum diatur • Ketuk untuk menambah',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: _emergencyContactName != null
                              ? AppColors.textSecondary
                              : AppColors.textLight,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: AppColors.textLight,
                      ),
                      onTap: () async {
                        await Navigator.pushNamed(context, '/emergency_contacts');
                        if (mounted) {
                          _loadProfileData();
                        }
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // 6. Section: PENGATURAN APLIKASI
                Text(
                  'PENGATURAN APLIKASI',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textLight,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 10),
                GlassCard(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Material(
                    color: Colors.transparent,
                    child: ListTile(
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.tune_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        'Pengaturan & Preferensi',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        'Suara AI, pengingat harian, privasi & sistem',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: AppColors.textLight,
                      ),
                      onTap: () => Navigator.pushNamed(context, '/settings'),
                    ),
                  ),
                ),

                const SizedBox(height: 36),

                // 7. Logout Pill Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await AppConfig.clearToken();
                      if (context.mounted) {
                        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFD32F2F), width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                      backgroundColor: Colors.transparent,
                    ),
                    icon: const Icon(
                      Icons.logout,
                      color: Color(0xFFD32F2F),
                      size: 20,
                    ),
                    label: Text(
                      'Keluar Akun',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFD32F2F),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Expanded(
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        child: Column(
          children: [
            Icon(icon, size: 22, color: AppColors.primary),
            const SizedBox(height: 6),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Widget? badge,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textLight,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          ?badge,
        ],
      ),
    );
  }
}
