import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../theme/app_colors.dart';
import '../../../../widgets/staggered_entrance.dart';

/// Section rendering voice call transcripts with user/EVA speech bubbles and expand/collapse support.
class DiaryTranscriptSection extends StatefulWidget {
  final List<Map<String, dynamic>> transcripts;
  final bool isSingleSession;
  final int initialLimit;

  const DiaryTranscriptSection({
    super.key,
    required this.transcripts,
    this.isSingleSession = false,
    this.initialLimit = 4,
  });

  @override
  State<DiaryTranscriptSection> createState() => _DiaryTranscriptSectionState();
}

class _DiaryTranscriptSectionState extends State<DiaryTranscriptSection> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final transcripts = widget.transcripts;
    final bool canExpand = transcripts.length > widget.initialLimit;
    final int displayCount = (_isExpanded || !canExpand)
        ? transcripts.length
        : widget.initialLimit;

    return StaggeredEntrance(
      index: 5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TRANSKRIP SUARA',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textLight,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  canExpand && !_isExpanded
                      ? '$displayCount dari ${transcripts.length}'
                      : '${transcripts.length} Dialog',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (transcripts.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  const Icon(Icons.forum_outlined, size: 36, color: Color(0xFFB0B7C3)),
                  const SizedBox(height: 8),
                  Text(
                    'Tidak ada transkrip rekaman suara tersimpan untuk sesi ini',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            )
          else ...[
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: displayCount,
              itemBuilder: (context, index) {
                final item = transcripts[index];
                final bool isUser = item['isUser'] == true ||
                    item['sender'] == 'user' ||
                    item['role'] == 'user';
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isUser
                        ? const Color(0xFFF0F2FF)
                        : Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isUser
                          ? AppColors.primary.withValues(alpha: 0.2)
                          : Colors.grey.shade200,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: isUser
                                      ? AppColors.primary
                                      : const Color(0xFFEADBFF),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isUser ? Icons.person : Icons.auto_awesome,
                                  size: 13,
                                  color: isUser ? Colors.white : AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isUser ? 'Kamu' : 'EVA AI',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          if (item['emotionTag'] != null &&
                              item['emotionTag'].toString().isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEADBFF),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                item['emotionTag'].toString(),
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        item['text']?.toString() ?? '',
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          color: AppColors.textPrimary,
                          height: 1.45,
                        ),
                      ),
                      if (!widget.isSingleSession &&
                          item['time'] != null &&
                          item['time'].toString().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Text(
                            item['time']?.toString() ?? '',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: AppColors.textLight,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
            if (canExpand) ...[
              const SizedBox(height: 4),
              InkWell(
                onTap: () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isExpanded
                            ? 'Tampilkan Lebih Sedikit'
                            : 'Lihat Selengkapnya (${transcripts.length - widget.initialLimit} pesan lainnya)',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
