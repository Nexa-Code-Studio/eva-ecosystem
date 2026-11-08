import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/entities/psychologist_entity.dart';

/// Reusable dense bin-packing review tags widget.
/// Guarantees at most [maxRows] lines. Intelligently selects combinations of tags
/// that fit within the available width. If a tag does not fit comfortably in the
/// remaining space, it is simply omitted ("tidak usah ditampilkan") to ensure zero overflow.
class DenseReviewTagsWrap extends StatelessWidget {
  final List<PatientReviewTag> tags;
  final int maxRows;
  final double fontSize;
  final double iconSize;
  final EdgeInsets padding;
  final double spacing;
  final double runSpacing;

  const DenseReviewTagsWrap({
    super.key,
    required this.tags,
    this.maxRows = 2,
    this.fontSize = 10.5,
    this.iconSize = 11,
    this.padding = const EdgeInsets.symmetric(horizontal: 7.5, vertical: 3.5),
    this.spacing = 6,
    this.runSpacing = 6,
  });

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        if (maxWidth <= 0 || maxWidth.isInfinite) {
          return const SizedBox.shrink();
        }

        final textScaler = MediaQuery.textScalerOf(context);
        final textStyle = GoogleFonts.plusJakartaSans(
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
        );

        // Measure each tag width with actual device TextScaler + safety cushion
        final tagWidths = <PatientReviewTag, double>{};
        for (final tag in tags) {
          final tp = TextPainter(
            text: TextSpan(text: tag.label, style: textStyle),
            textDirection: TextDirection.ltr,
            textScaler: textScaler,
            maxLines: 1,
          )..layout();
          // Total conservative width: text + icon + gap + horizontal padding + border + safe buffer
          tagWidths[tag] = tp.width + iconSize + 5.0 + padding.horizontal + 2.0 + 6.0;
        }

        // Greedy knapsack bin-packing: pack candidates into up to maxRows
        // Strictly omit any tag that cannot fit completely within the line budget
        final remaining = List<PatientReviewTag>.of(tags);
        final rows = <List<PatientReviewTag>>[];

        for (int r = 0; r < maxRows; r++) {
          if (remaining.isEmpty) break;

          final currentRow = <PatientReviewTag>[];
          double currentWidth = 0.0;

          while (remaining.isNotEmpty) {
            final spaceLeft = currentRow.isEmpty
                ? maxWidth
                : (maxWidth - currentWidth - spacing);

            if (spaceLeft <= 0) break;

            // Find best candidate that fits within spaceLeft
            PatientReviewTag? bestCandidate;
            double bestCandidateWidth = 0.0;

            for (final candidate in remaining) {
              final w = tagWidths[candidate] ?? 70.0;
              if (w <= spaceLeft) {
                // Pick candidate that fills the line most densely
                if (bestCandidate == null || w > bestCandidateWidth) {
                  bestCandidate = candidate;
                  bestCandidateWidth = w;
                }
              }
            }

            if (bestCandidate != null) {
              currentRow.add(bestCandidate);
              currentWidth += (currentRow.length == 1
                  ? bestCandidateWidth
                  : bestCandidateWidth + spacing);
              remaining.remove(bestCandidate);
            } else {
              // If no candidate fits into the remaining space, stop this row!
              // Do NOT force any candidate into the row.
              break;
            }
          }

          if (currentRow.isNotEmpty) {
            rows.add(currentRow);
          } else {
            // Even on an empty row, no remaining tag fits in maxWidth.
            // Do not display any further tags.
            break;
          }
        }

        if (rows.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: rows.asMap().entries.map((entry) {
            final rowIndex = entry.key;
            final rowTags = entry.value;
            final isLastRow = rowIndex == rows.length - 1;

            return Padding(
              padding: EdgeInsets.only(bottom: isLastRow ? 0 : runSpacing),
              child: Wrap(
                spacing: spacing,
                runSpacing: runSpacing,
                children: rowTags.map((tag) {
                  final isPos = tag.isPositive;
                  final bgColor = isPos ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2);
                  final borderColor = isPos ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA);
                  final textColor = isPos ? const Color(0xFF15803D) : const Color(0xFFB91C1C);
                  final iconColor = isPos ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
                  final icon = isPos ? Icons.thumb_up_alt_rounded : Icons.thumb_down_alt_rounded;

                  return Container(
                    padding: padding,
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: iconSize, color: iconColor),
                        const SizedBox(width: 4.5),
                        ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: maxWidth > 40 ? maxWidth - iconSize - 20 : 120),
                          child: Text(
                            tag.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: fontSize,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
