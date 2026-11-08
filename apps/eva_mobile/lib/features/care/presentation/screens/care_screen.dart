import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../config/app_config.dart';
import '../../../../theme/app_colors.dart';
import '../../../auth/presentation/screens/profile_screen.dart';
import '../../../home/presentation/widgets/profile_dropdown_modal.dart';
import '../providers/care_provider.dart';
import '../widgets/care_quick_actions.dart';
import '../widgets/psychologist_card.dart';
import '../widgets/booking_consultation_sheet.dart';
import 'psychologist_detail_screen.dart';

class CareScreen extends ConsumerStatefulWidget {
  final GlobalKey? firstPsychologistCardKey;

  const CareScreen({
    super.key,
    this.firstPsychologistCardKey,
  });

  @override
  ConsumerState<CareScreen> createState() => CareScreenState();
}

class CareScreenState extends ConsumerState<CareScreen> {
  final TextEditingController _searchController = TextEditingController();
  final GlobalKey _profileButtonKey = GlobalKey();
  OverlayEntry? _profileOverlayEntry;

  String _userName = 'Pengguna EVA';
  String _userEmail = 'user@eva.ai';

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _removeProfileOverlay();
    super.dispose();
  }

  Future<void> _loadUserInfo() async {
    final name = await AppConfig.getUserName();
    final email = await AppConfig.getUserEmail();
    if (mounted) {
      setState(() {
        if (name != null && name.isNotEmpty) _userName = name;
        if (email != null && email.isNotEmpty) _userEmail = email;
      });
    }
  }

  String get _userInitials {
    final parts = _userName.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return 'EV';
  }

  void _removeProfileOverlay() {
    _profileOverlayEntry?.remove();
    _profileOverlayEntry = null;
  }

  void _toggleProfileDropdown() {
    if (_profileOverlayEntry != null) {
      _removeProfileOverlay();
      return;
    }

    final renderBox = _profileButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);

    _profileOverlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _removeProfileOverlay,
            ),
          ),
          Positioned(
            top: offset.dy + size.height + 8,
            right: 16,
            child: Material(
              color: Colors.transparent,
              child: ProfileDropdownModal(
                userName: _userName,
                userEmail: _userEmail,
                onProfileTap: () {
                  _removeProfileOverlay();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfileScreen()),
                  );
                },
                onEmergencyContactsTap: () {
                  _removeProfileOverlay();
                  Navigator.pushNamed(context, '/emergency_contacts');
                },
                onSettingsTap: () {
                  _removeProfileOverlay();
                  Navigator.pushNamed(context, '/settings');
                },
                onCoinTap: () {
                  _removeProfileOverlay();
                  Navigator.pushNamed(context, '/coin_purchase');
                },
                onLogoutTap: () {
                  _removeProfileOverlay();
                  Navigator.pushReplacementNamed(context, '/login');
                },
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_profileOverlayEntry!);
  }

  @override
  Widget build(BuildContext context) {
    final activeFilter = ref.watch(careCategoryFilterProvider);
    final psychologistsAsync = ref.watch(psychologistsListProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            ref.invalidate(psychologistsListProvider);
            ref.read(consultationSessionsProvider.notifier).loadSessions();
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // 1. Header with Profile Dropdown
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Layanan Konseling',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Konseling psikolog berlisensi & relawan sebaya',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        key: _profileButtonKey,
                        onTap: _toggleProfileDropdown,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primaryContainer,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              _userInitials,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 2. Quick Action Hub (Jadwal, Riwayat, Koin, Panduan)
              const SliverToBoxAdapter(
                child: CareQuickActions(),
              ),

              const SliverToBoxAdapter(
                child: SizedBox(height: 10),
              ),

              // 3. Search Bar & Filter Chips (Psikolog, Relawan)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Temukan Psikolog & Relawan',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Search TextField
                      TextField(
                        controller: _searchController,
                        onChanged: (val) {
                          ref.read(careSearchQueryProvider.notifier).state = val;
                        },
                        decoration: InputDecoration(
                          hintText: 'Cari nama konselor, ulasan pasien, atau isu...',
                          hintStyle: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: AppColors.textLight,
                          ),
                          prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    ref.read(careSearchQueryProvider.notifier).state = '';
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Filter Chips: Semua, Psikolog, Relawan
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: [
                            _buildFilterChip('Semua', 'all', activeFilter),
                            const SizedBox(width: 8),
                            _buildFilterChip('Psikolog', 'psychologist', activeFilter),
                            const SizedBox(width: 8),
                            _buildFilterChip('Relawan', 'volunteer', activeFilter),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 4. Main Directory List of Psychologists / Volunteers
              psychologistsAsync.when(
                data: (psychologists) {
                  if (psychologists.isEmpty) {
                    return _buildEmptyState('Tidak ada psikolog atau relawan yang cocok');
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final psychologist = psychologists[index];
                          return Padding(
                            key: index == 0 ? widget.firstPsychologistCardKey : null,
                            padding: const EdgeInsets.only(bottom: 14),
                            child: PsychologistCard(
                              psychologist: psychologist,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PsychologistDetailScreen(
                                      psychologist: psychologist,
                                    ),
                                  ),
                                );
                              },
                              onBookTap: () {
                                BookingConsultationSheet.show(context, psychologist);
                              },
                            ),
                          );
                        },
                        childCount: psychologists.length,
                      ),
                    ),
                  );
                },
                loading: () => SliverToBoxAdapter(
                  key: widget.firstPsychologistCardKey,
                  child: const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                  ),
                ),
                error: (err, _) => SliverToBoxAdapter(
                  child: Center(child: Text('Gagal memuat konselor: $err')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String key, String activeKey) {
    final isSelected = activeKey == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        ref.read(careCategoryFilterProvider.notifier).state =
            selected ? key : 'all';
      },
      selectedColor: AppColors.primary,
      checkmarkColor: Colors.white,
      backgroundColor: Colors.white,
      labelStyle: GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected ? Colors.white : AppColors.textPrimary,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              const Icon(Icons.search_off_rounded, size: 48, color: Color(0xFF94A3B8)),
              const SizedBox(height: 12),
              Text(
                message,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
