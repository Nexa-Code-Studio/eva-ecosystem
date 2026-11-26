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
    final activeAvailability = ref.watch(careAvailabilityFilterProvider);
    final activeSortBy = ref.watch(careSortByProvider);
    final activeLevelTier = ref.watch(careLevelTierFilterProvider);
    final searchQuery = ref.watch(careSearchQueryProvider);
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
                            'Konseling psikolog klinis berlisensi & terverifikasi',
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

              // 3. Search Bar & Availability / Rating / Level Filter Chips
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Temukan Psikolog',
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
                          hintText: 'Cari nama psikolog, keahlian, atau ulasan...',
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

                      // Filter Chips: Availability + Rating Terbaik + Level
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: [
                            _buildAvailabilityChip('Semua', 'all', activeAvailability),
                            const SizedBox(width: 8),
                            _buildAvailabilityChip(
                              'Saat Ini',
                              'available_now',
                              activeAvailability,
                              leadingDotColor: const Color(0xFF10B981),
                            ),
                            const SizedBox(width: 8),
                            _buildAvailabilityChip('Hari Ini', 'available_today', activeAvailability),
                            const SizedBox(width: 8),
                            _buildAvailabilityChip('Besok', 'available_tomorrow', activeAvailability),
                            const SizedBox(width: 10),
                            Container(
                              width: 1,
                              height: 22,
                              color: const Color(0xFFE2E8F0),
                            ),
                            const SizedBox(width: 10),
                            _buildRatingSortChip(activeSortBy == 'rating'),
                            const SizedBox(width: 8),
                            _buildLevelSelectorChip(
                              activeLevelTier,
                              psychologistsAsync.valueOrNull ?? const [],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 4. Main Directory List of Licensed Psychologists
              psychologistsAsync.when(
                data: (psychologists) {
                  if (psychologists.isEmpty) {
                    final hasActiveFilters = activeAvailability != 'all' ||
                        activeLevelTier != null ||
                        activeSortBy != 'default' ||
                        searchQuery.trim().isNotEmpty;
                    return _buildEmptyState(
                      'Tidak ada psikolog yang cocok',
                      showReset: hasActiveFilters,
                    );
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
                              preferTomorrowTag:
                                  activeAvailability == 'available_tomorrow',
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
                loading: () => const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                  ),
                ),
                error: (err, _) => SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.cloud_off_rounded, size: 36, color: AppColors.error),
                          const SizedBox(height: 10),
                          Text(
                            'Gagal Memuat Daftar Konselor',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            err.toString(),
                            textAlign: TextAlign.center,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 14),
                          ElevatedButton.icon(
                            onPressed: () {
                              ref.invalidate(psychologistsListProvider);
                              ref.read(consultationSessionsProvider.notifier).loadSessions();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: const Icon(Icons.refresh_rounded, size: 17),
                            label: const Text('Coba Lagi'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvailabilityChip(
    String label,
    String key,
    String activeKey, {
    Color? leadingDotColor,
  }) {
    final isSelected = activeKey == key;
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leadingDotColor != null) ...[
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : leadingDotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
          ],
          Text(label),
        ],
      ),
      selected: isSelected,
      showCheckmark: false,
      onSelected: (selected) {
        ref.read(careAvailabilityFilterProvider.notifier).state =
            selected ? key : 'all';
      },
      selectedColor: AppColors.primary,
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

  Widget _buildRatingSortChip(bool isSelected) {
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.star_rounded,
            size: 15,
            color: isSelected ? Colors.white : const Color(0xFFF59E0B),
          ),
          const SizedBox(width: 4),
          const Text('Rating Terbaik'),
        ],
      ),
      selected: isSelected,
      showCheckmark: false,
      onSelected: (selected) {
        ref.read(careSortByProvider.notifier).state =
            selected ? 'rating' : 'default';
      },
      selectedColor: AppColors.primary,
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

  static const Map<int, String> _defaultLevelNames = {
    1: 'Junior Practitioner',
    2: 'Registered Counselor',
    3: 'Senior Specialist',
    4: 'Master Expert',
  };

  Map<int, String> _resolvedLevelOptions(List<dynamic> loadedItems) {
    final map = <int, String>{..._defaultLevelNames};
    for (final item in loadedItems) {
      if (item.levelTier != null &&
          item.levelName != null &&
          (item.levelName as String).trim().isNotEmpty) {
        map[item.levelTier as int] = (item.levelName as String).trim();
      }
    }
    return map;
  }

  Widget _buildLevelSelectorChip(int? activeTier, List<dynamic> loadedItems) {
    final isSelected = activeTier != null;
    final options = _resolvedLevelOptions(loadedItems);
    final labelText = isSelected
        ? 'Lv.$activeTier ${options[activeTier] ?? ''}'.trim()
        : 'Level';

    return ActionChip(
      onPressed: () => _showLevelPickerSheet(activeTier, options),
      backgroundColor: isSelected ? AppColors.primary : Colors.white,
      side: BorderSide(
        color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.workspace_premium_rounded,
            size: 14,
            color: isSelected ? Colors.white : const Color(0xFFD97706),
          ),
          const SizedBox(width: 4),
          Text(
            labelText,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? Colors.white : AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 2),
          Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 16,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ],
      ),
    );
  }

  void _showLevelPickerSheet(int? activeTier, Map<int, String> levelOptions) {
    final sortedTiers = levelOptions.keys.toList()..sort();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Filter Level Psikolog',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.layers_clear_rounded, color: AppColors.primary),
                title: Text(
                  'Semua Level',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    fontWeight: activeTier == null ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                trailing: activeTier == null
                    ? const Icon(Icons.check_circle_rounded, color: AppColors.primary)
                    : null,
                onTap: () {
                  ref.read(careLevelTierFilterProvider.notifier).state = null;
                  Navigator.pop(ctx);
                },
              ),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              ...sortedTiers.map((tier) {
                final selected = activeTier == tier;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 15,
                    backgroundColor: const Color(0xFFFEF3C7),
                    child: Text(
                      'L$tier',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFB45309),
                      ),
                    ),
                  ),
                  title: Text(
                    levelOptions[tier] ?? 'Level $tier',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.5,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  trailing: selected
                      ? const Icon(Icons.check_circle_rounded, color: AppColors.primary)
                      : null,
                  onTap: () {
                    ref.read(careLevelTierFilterProvider.notifier).state = tier;
                    Navigator.pop(ctx);
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message, {bool showReset = false}) {
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
              if (showReset) ...[
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () {
                    _searchController.clear();
                    ref.read(careSearchQueryProvider.notifier).state = '';
                    ref.read(careAvailabilityFilterProvider.notifier).state = 'all';
                    ref.read(careSortByProvider.notifier).state = 'default';
                    ref.read(careLevelTierFilterProvider.notifier).state = null;
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 17),
                  label: const Text('Reset Filter'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
