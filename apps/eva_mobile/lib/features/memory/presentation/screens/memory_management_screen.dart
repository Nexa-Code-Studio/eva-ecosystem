import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../theme/app_colors.dart';
import '../../../../widgets/app_back_button.dart';
import '../../../../widgets/app_snack_bar.dart';
import '../../../../widgets/glass_card.dart';
import '../../domain/entities/memory_item_entity.dart';
import '../providers/memory_provider.dart';

class MemoryManagementScreen extends ConsumerStatefulWidget {
  const MemoryManagementScreen({super.key});

  @override
  ConsumerState<MemoryManagementScreen> createState() => _MemoryManagementScreenState();
}

class _MemoryManagementScreenState extends ConsumerState<MemoryManagementScreen> {
  MemoryCategory? _selectedCategory;

  void _showDeleteDialog(MemoryItemEntity item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Hapus Fakta Memori?', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: Text(
          'Fakta ini akan dihapus secara permanen dari penyimpanan lokal terenkripsi perangkat Anda.',
          style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Batal', style: GoogleFonts.inter(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD32F2F)),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(memoryNotifierProvider.notifier).deleteMemory(item.id);
              if (mounted) {
                AppSnackBar.showSuccess(context, 'Fakta memori berhasil dihapus.');
              }
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showClearAllDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Bersihkan Seluruh Memori?', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: Text(
          'Seluruh riwayat fakta personalisasi emosional lokal akan dihapus permanen. Tindakan ini tidak dapat dibatalkan.',
          style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Batal', style: GoogleFonts.inter(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD32F2F)),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(memoryNotifierProvider.notifier).clearAll();
              if (mounted) {
                AppSnackBar.showSuccess(context, 'Seluruh memori lokal berhasil dibersihkan.');
              }
            },
            child: const Text('Bersihkan Semua', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final memoryState = ref.watch(memoryNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const Center(child: AppBackButton()),
        title: Text(
          'Memori Personal EVA',
          style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),
        actions: [
          IconButton(
            tooltip: 'Bersihkan Semua',
            icon: const Icon(Icons.delete_sweep_outlined, color: AppColors.error),
            onPressed: _showClearAllDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Category selector chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _buildFilterChip(
                  label: 'Semua',
                  isSelected: _selectedCategory == null,
                  onSelected: () => setState(() => _selectedCategory = null),
                ),
                ...MemoryCategory.values.map(
                  (cat) => _buildFilterChip(
                    label: cat.label,
                    isSelected: _selectedCategory == cat,
                    onSelected: () => setState(() => _selectedCategory = cat),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: memoryState.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Text('Gagal memuat memori: $err', style: GoogleFonts.inter(color: Colors.red)),
              ),
              data: (items) {
                final filtered = _selectedCategory == null
                    ? items
                    : items.where((i) => i.category == _selectedCategory).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.psychology_outlined, size: 64, color: AppColors.textSecondary.withValues(alpha: 0.5)),
                          const SizedBox(height: 16),
                          Text(
                            'Belum Ada Fakta Memori Tersimpan',
                            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'EVA hanya mengingat fakta penting atas konfirmasi Anda saat sesi konseling berlangsung.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: filtered.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (ctx, idx) {
                    final item = filtered[idx];
                    final isActive = item.status == MemoryStatus.active;

                    return GlassCard.surface(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  item.category.label,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                              Row(
                                children: [
                                  Text(
                                    isActive ? 'Aktif' : 'Historis',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: isActive ? AppColors.successDark : AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Switch(
                                    value: isActive,
                                    activeThumbColor: AppColors.successDark,
                                    onChanged: (_) {
                                      ref.read(memoryNotifierProvider.notifier).toggleStatus(item);
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                                    onPressed: () => _showDeleteDialog(item),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            item.factText,
                            style: GoogleFonts.inter(fontSize: 14, height: 1.4, color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Icon(Icons.verified_outlined, size: 14, color: AppColors.textSecondary),
                              const SizedBox(width: 4),
                              Text(
                                item.sourceVerification.label,
                                style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary),
                              ),
                              const Spacer(),
                              Text(
                                'Ditinjau: ${item.updatedAt.day}/${item.updatedAt.month}/${item.updatedAt.year}',
                                style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onSelected,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onSelected(),
        selectedColor: AppColors.primary.withValues(alpha: 0.15),
        labelStyle: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          color: isSelected ? AppColors.primary : AppColors.textSecondary,
        ),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected ? AppColors.primary : AppColors.borderSoft,
          ),
        ),
      ),
    );
  }
}
