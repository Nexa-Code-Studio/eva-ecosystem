import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
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
      backgroundColor: const Color(0xFFF8F9FE),
      body: SafeArea(
        child: Column(
          children: [
            // Soft Search Box (Clean edge-to-edge layout)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F6FB),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Cari nama pasien, usia, atau keluhan...',
                    hintStyle: TextStyle(fontSize: 13, color: AppColors.textLight),
                    prefixIcon: Icon(Icons.search_rounded, color: AppColors.primary, size: 20),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 13, horizontal: 16),
                  ),
                  onChanged: (val) {
                    setState(() => _searchQuery = val.toLowerCase());
                  },
                ),
              ),
            ),

            // Soft Pill Filter Bar
            Container(
              color: Colors.white,
              padding: const EdgeInsets.only(left: 20, right: 20, bottom: 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['Semua', 'Akses Terbuka', 'Akses Terkunci', 'Krisis Darurat'].map((filter) {
                    final isSelected = _selectedFilter == filter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedFilter = filter),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primary : const Color(0xFFF4F6FB),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            filter,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? Colors.white : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Patient Cards List
            Expanded(
              child: patientsAsync.when(
                data: (patients) {
                  final filtered = patients.where((p) {
                    final matchesSearch = p.name.toLowerCase().contains(_searchQuery) ||
                        p.chiefComplaint.toLowerCase().contains(_searchQuery);
                    if (!matchesSearch) return false;

                    if (_selectedFilter == 'Akses Terbuka') return p.hasConsent;
                    if (_selectedFilter == 'Akses Terkunci') return !p.hasConsent;
                    if (_selectedFilter == 'Krisis Darurat') return p.isHighRisk;
                    return true;
                  }).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.person_search_rounded, size: 48, color: AppColors.textLight),
                          SizedBox(height: 10),
                          Text('Tidak ada pasien yang sesuai filter.', style: TextStyle(color: AppColors.textSecondary)),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final p = filtered[index];

                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: p.isHighRisk
                                ? AppColors.highRiskRed.withValues(alpha: 0.2)
                                : const Color(0xFFECEFF8),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: p.isHighRisk
                                  ? AppColors.highRiskRed.withValues(alpha: 0.04)
                                  : Colors.black.withValues(alpha: 0.02),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () {
                              Navigator.of(context).pushNamed(
                                '/counselor-patient-detail',
                                arguments: p.id,
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 24,
                                        backgroundColor: p.isHighRisk
                                            ? AppColors.highRiskBg
                                            : AppColors.primaryContainer,
                                        child: Text(
                                          p.name.substring(0, 1),
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 16,
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
                                              '${p.name}, ${p.age} thn',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${p.totalCompletedSessions} Sesi Selesai • ${p.gender}',
                                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
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

                                  // Chief Complaint Box (Soft light background)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF7F8FC),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.chat_bubble_outline_rounded,
                                            size: 14, color: AppColors.primary),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            p.chiefComplaint,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textPrimary,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (p.isHighRisk) ...[
                                    const SizedBox(height: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.highRiskBg,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          Icon(Icons.crisis_alert_rounded, size: 14, color: AppColors.highRiskRed),
                                          SizedBox(width: 6),
                                          Text(
                                            'Peringatan: Indikasi Krisis Emosional Akut',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.highRiskRed,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
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
