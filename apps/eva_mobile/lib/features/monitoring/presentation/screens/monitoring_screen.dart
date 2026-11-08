import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:eva_mobile/core/utils/responsive_layout_helper.dart';
import 'package:eva_mobile/features/dass/presentation/providers/dass_provider.dart';
import 'package:eva_mobile/features/monitoring/domain/entities/monitoring_data_entity.dart';
import 'package:eva_mobile/features/monitoring/presentation/providers/monitoring_provider.dart';
import 'package:eva_mobile/features/monitoring/presentation/widgets/monitoring_dass_card.dart';
import 'package:eva_mobile/features/monitoring/presentation/widgets/stacked_emotion_chart_painter.dart';
import 'package:eva_mobile/theme/app_colors.dart';
import 'package:eva_mobile/widgets/glass_card.dart';
import 'package:eva_mobile/widgets/skeleton_shimmer.dart';

class MonitoringScreen extends ConsumerStatefulWidget {
  final GlobalKey? dassCardKey;

  const MonitoringScreen({
    super.key,
    this.dassCardKey,
  });

  @override
  ConsumerState<MonitoringScreen> createState() => MonitoringScreenState();
}

class MonitoringScreenState extends ConsumerState<MonitoringScreen>
    with WidgetsBindingObserver {
  late final GlobalKey _defaultDassCardKey = GlobalKey(debugLabel: 'monitoringDassCard');
  GlobalKey get dassCardKey => widget.dassCardKey ?? _defaultDassCardKey;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      refresh();
    }
  }

  void refresh() {
    ref.invalidate(monitoringDataProvider);
    ref.invalidate(dassAssessmentNotifierProvider);
  }

  // 7 Emotion parameters color mapping matching backend & design system
  final List<Map<String, dynamic>> _emotionLegend = const [
    {'key': 'happy', 'name': 'Bahagia & Senang', 'emoji': '😃', 'color': Color(0xFFFFB800)},
    {'key': 'netral', 'name': 'Netral & Tenang', 'emoji': '😌', 'color': Color(0xFF4ECDC4)},
    {'key': 'fear', 'name': 'Cemas & Takut', 'emoji': '😰', 'color': Color(0xFF6C63FF)},
    {'key': 'sadness', 'name': 'Sedih', 'emoji': '😢', 'color': Color(0xFF74B9FF)},
    {'key': 'surprise', 'name': 'Terkejut', 'emoji': '😲', 'color': Color(0xFFA29BFE)},
    {'key': 'anger', 'name': 'Marah', 'emoji': '😡', 'color': Color(0xFFFF7675)},
    {'key': 'disgusted', 'name': 'Jijik / Muak', 'emoji': '🤢', 'color': Color(0xFF55EFC4)},
  ];

  Color _parseHex(String? hex, Color fallback) {
    if (hex == null || hex.isEmpty) return fallback;
    try {
      final clean = hex.replaceFirst('#', '');
      if (clean.length == 6) {
        return Color(int.parse('FF$clean', radix: 16));
      }
      return Color(int.parse(clean, radix: 16));
    } catch (_) {
      return fallback;
    }
  }

  List<Color> _getGradientColors(int level) {
    switch (level) {
      case 5:
        return const [Color(0xFFC8E6C9), Color(0xFF81C784)];
      case 4:
        return const [Color(0xFFE8F5E9), Color(0xFFA5D6A7)];
      case 3:
        return const [Color(0xFFFFF8E1), Color(0xFFFFE082)];
      case 2:
        return const [Color(0xFFFFE0B2), Color(0xFFFFB74D)];
      case 1:
        return const [Color(0xFFFFEBEE), Color(0xFFFFCDD2)];
      case 0:
      default:
        return const [Color(0xFFF1F5F9), Color(0xFFE2E8F0)];
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedPeriod = ref.watch(selectedPeriodProvider);
    final asyncData = ref.watch(monitoringDataProvider);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
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
          child: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async {
              ref.invalidate(monitoringDataProvider);
              try {
                await ref.read(monitoringDataProvider.future);
              } catch (_) {}
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 100.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                        // Title & Subtitle
                        Text(
                          'Ritem & Tren Emosional',
                          style: GoogleFonts.inter(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Grafik dinamika 7 emosi dan tingkat risiko kesehatan mentalmu.',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // PERIOD FILTER CHIPS
                        Row(
                          children: [
                            _buildPeriodChip('today', 'Hari Ini', selectedPeriod),
                            const SizedBox(width: 8),
                            _buildPeriodChip('week', 'Minggu Ini', selectedPeriod),
                            const SizedBox(width: 8),
                            _buildPeriodChip('month', 'Bulan Ini', selectedPeriod),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // ASYNC CONTENT
                        asyncData.when(
                          data: (data) => _buildMonitoringContent(context, data),
                          loading: () => _buildLoadingState(),
                          error: (error, _) => _buildErrorState(error),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
  }

  Widget _buildPeriodChip(String id, String label, String activePeriod) {
    final isSelected = id == activePeriod;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          ref.read(selectedPeriodProvider.notifier).state = id;
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(999),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMonitoringContent(BuildContext context, MonitoringDataEntity data) {
    final emotionalCenter = data.emotionalCenter;
    final int level = emotionalCenter.level;
    final Color textColor = _parseHex(emotionalCenter.textColorHex, const Color(0xFF2E7D32));
    final List<Color> gradientColors = _getGradientColors(level);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. RINGKASAN AI
        GlassCard(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Icon + Title + Period Badge
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      size: 16,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'RINGKASAN AI',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: AppColors.primary,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      data.periodLabel,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Body content text cleanly below icon and title
              Text(
                data.summary,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                  height: 1.55,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 2. LEMBAR EVALUASI DASS-21
        MonitoringDassCard(
          key: dassCardKey,
          selectedPeriod: ref.watch(selectedPeriodProvider),
        ),
        const SizedBox(height: 16),

        // 3. PUSAT EMOSIONAL HARIAN
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: gradientColors.last.withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.tune_rounded,
                    size: 20,
                    color: textColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'PUSAT EMOSIONAL',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: textColor.withValues(alpha: 0.8),
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                emotionalCenter.status,
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                emotionalCenter.description,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: textColor.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 16),

              // 5-Segment Level Pills (Red to Green Spectrum)
              Row(
                children: List.generate(5, (index) {
                  final segLevel = index + 1;
                  final bool isSel = segLevel == level;
                  final colors = const [
                    Color(0xFFD32F2F), // 1: Sangat Buruk (Red)
                    Color(0xFFE57373), // 2: Buruk
                    Color(0xFFFFB74D), // 3: Cukup (Amber)
                    Color(0xFF81C784), // 4: Baik (Light Green)
                    Color(0xFF4CAF50), // 5: Sangat Baik (Green)
                  ];

                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      height: 28,
                      decoration: BoxDecoration(
                        color: colors[index].withValues(alpha: isSel ? 1.0 : 0.4),
                        borderRadius: BorderRadius.circular(10),
                        border: isSel ? Border.all(color: Colors.white, width: 2) : null,
                      ),
                      child: isSel
                          ? const Icon(Icons.check, color: Colors.white, size: 16)
                          : null,
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 4. TINGKAT RISIKO KESEHATAN MENTAL
        GlassCard(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.health_and_safety_outlined,
                    size: 20,
                    color: Color(0xFFD32F2F),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'TINGKAT RISIKO KESEHATAN MENTAL',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textLight,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              ...data.risks.map((r) {
                final double pct = r.percent;
                final Color barColor = _parseHex(r.colorHex, const Color(0xFFFB8C00));
                final Color badgeBg = _parseHex(r.badgeBgHex, const Color(0xFFFFF3E0));

                return Padding(
                  padding: const EdgeInsets.only(bottom: 14.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            r.name,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: badgeBg,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              r.levelLabel,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: barColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 8,
                          backgroundColor: const Color(0xFFE2E4F0),
                          valueColor: AlwaysStoppedAnimation<Color>(barColor),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 4),
              Text(
                'EVA merekomendasikan jeda istirahat teratur dan latihan pernapasan untuk menstabilkan kondisi psikologis.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 5. STACKED BAR CHART RITEM SUASANA HATI (7 Emosi)
        GlassCard(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ritem 7 Emosi',
                          style: GoogleFonts.inter(
                            fontSize: context.responsiveFont(12),
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Proporsi emosi per interval ${data.periodLabel}',
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEADBFF),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '7 PARAMETER',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Custom Painted Vertical Stacked Bar Chart
              SizedBox(
                height: 160,
                width: double.infinity,
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: StackedEmotionChartPainter(
                      chartData: data.chartData,
                      emotionColors: _emotionLegend.map((e) => e['color'] as Color).toList(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // X-Axis Labels Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: data.xLabels.map((lbl) {
                  return Flexible(
                    child: Text(
                      lbl,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textLight,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),

              const Divider(height: 1, color: Color(0xFFEBECEF)),
              const SizedBox(height: 14),

              // Legend Key for 7 Emotions
              Text(
                'KUNCI WARNA EMOSI',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textLight,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),

              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: _emotionLegend.map((item) {
                  final Color solidColor = item['color'] as Color;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: solidColor,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(item['emoji'], style: const TextStyle(fontSize: 12)),
                        const SizedBox(width: 4),
                        Text(
                          item['name'],
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }


  Widget _buildLoadingState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Ringkasan AI Skeleton
        SkeletonShimmerHost(
          child: GlassCard(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const SkeletonCircle(size: 32),
                    const SizedBox(width: 10),
                    const SkeletonLine(width: 120, height: 14),
                  ],
                ),
                const SizedBox(height: 14),
                const SkeletonLine(width: double.infinity, height: 13),
                const SizedBox(height: 8),
                const SkeletonLine(width: 200, height: 13),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 2. Lembar Evaluasi DASS-21 (mounted immediately with key)
        MonitoringDassCard(
          key: dassCardKey,
          selectedPeriod: ref.watch(selectedPeriodProvider),
        ),
        const SizedBox(height: 16),

        // 3. Trend Chart & Metrics Skeleton
        SkeletonShimmerHost(
          child: Column(
            children: [
              GlassCard(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        SkeletonLine(width: 140, height: 16),
                        SkeletonBox(width: 70, height: 26, borderRadius: 8),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const SkeletonBox(width: double.infinity, height: 160, borderRadius: 12),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: GlassCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: const [
                          SkeletonLine(width: 60, height: 12),
                          SizedBox(height: 8),
                          SkeletonLine(width: 40, height: 18),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: GlassCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: const [
                          SkeletonLine(width: 60, height: 12),
                          SizedBox(height: 8),
                          SkeletonLine(width: 40, height: 18),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(Object error) {
    return GlassCard(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.textLight),
          const SizedBox(height: 12),
          Text(
            'Gagal Memuat Data Tren',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Pastikan koneksi internet atau server backend aktif.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              ref.invalidate(monitoringDataProvider);
            },
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Coba Lagi'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
