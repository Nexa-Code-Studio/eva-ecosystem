import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/status_badge.dart';
import '../providers/patient_provider.dart';

class PatientListScreen extends ConsumerStatefulWidget {
  const PatientListScreen({super.key});

  @override
  ConsumerState<PatientListScreen> createState() => _PatientListScreenState();
}

class _PatientListScreenState extends ConsumerState<PatientListScreen> {
  String _selectedFilter = 'Semua';
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final patientsAsync = ref.watch(patientsListProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Daftar Pasien Konseling', style: AppTypography.headingMedium),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Input
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Cari nama pasien atau keluhan...',
                  hintStyle: AppTypography.bodyMedium,
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.divider),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.divider),
                  ),
                ),
                onChanged: (val) {
                  setState(() => _searchQuery = val.toLowerCase());
                },
              ),
            ),

            // Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Row(
                children: ['Semua', 'Izin Diberikan', 'Izin Terkunci', 'Krisis Darurat']
                    .map((filter) {
                  final isSelected = _selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: isSelected,
                      label: Text(filter),
                      selectedColor: AppColors.primaryContainer,
                      checkmarkColor: AppColors.primary,
                      labelStyle: AppTypography.bodySmall.copyWith(
                        color: isSelected ? AppColors.primary : AppColors.textPrimary,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      ),
                      onSelected: (_) {
                        setState(() => _selectedFilter = filter);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),

            // Patient List
            Expanded(
              child: patientsAsync.when(
                data: (patients) {
                  final filtered = patients.where((p) {
                    final matchesSearch = p.name.toLowerCase().contains(_searchQuery) ||
                        p.chiefComplaint.toLowerCase().contains(_searchQuery);
                    if (!matchesSearch) return false;

                    if (_selectedFilter == 'Izin Diberikan') return p.hasConsent;
                    if (_selectedFilter == 'Izin Terkunci') return !p.hasConsent;
                    if (_selectedFilter == 'Krisis Darurat') return p.isHighRisk;
                    return true;
                  }).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Text(
                        'Tidak ada pasien yang sesuai filter.',
                        style: AppTypography.bodyMedium,
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final p = filtered[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: GlassCard(
                          padding: const EdgeInsets.all(16),
                          onTap: () {
                            Navigator.of(context).pushNamed(
                              '/counselor-patient-detail',
                              arguments: p.id,
                            );
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 22,
                                    backgroundColor: p.isHighRisk
                                        ? AppColors.highRiskBg
                                        : AppColors.primaryContainer,
                                    child: Text(
                                      p.name.substring(0, 1),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: p.isHighRisk
                                            ? AppColors.highRiskRed
                                            : AppColors.primary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${p.name} (${p.age} Thn, ${p.gender})',
                                          style: AppTypography.headingSmall,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Sesi Terakhir: ${p.lastSessionDate.day}/${p.lastSessionDate.month}/${p.lastSessionDate.year} • ${p.totalCompletedSessions} Sesi Selesai',
                                          style: AppTypography.bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                  p.hasConsent
                                      ? StatusBadge.consentGranted('Akses Aktif')
                                      : StatusBadge.consentLocked('Terkunci'),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.notes_rounded,
                                        size: 16, color: AppColors.textSecondary),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        p.chiefComplaint,
                                        style: AppTypography.bodySmall.copyWith(
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (p.isHighRisk) ...[
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    StatusBadge.highRisk('Perhatian: Tingkat Distres Akut'),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
