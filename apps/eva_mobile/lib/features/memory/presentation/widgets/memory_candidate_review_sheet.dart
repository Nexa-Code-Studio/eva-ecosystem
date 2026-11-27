import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../theme/app_colors.dart';
import '../../domain/entities/memory_item_entity.dart';

class MemoryCandidateReviewSheet extends StatefulWidget {
  final List<MemoryItemEntity> candidates;
  final Function(MemoryItemEntity candidate, String decision, {String? editedText, MemoryCategory? editedCategory}) onDecision;

  const MemoryCandidateReviewSheet({
    super.key,
    required this.candidates,
    required this.onDecision,
  });

  static Future<void> show({
    required BuildContext context,
    required List<MemoryItemEntity> candidates,
    required Function(MemoryItemEntity candidate, String decision, {String? editedText, MemoryCategory? editedCategory}) onDecision,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MemoryCandidateReviewSheet(
        candidates: candidates,
        onDecision: onDecision,
      ),
    );
  }

  @override
  State<MemoryCandidateReviewSheet> createState() => _MemoryCandidateReviewSheetState();
}

class _MemoryCandidateReviewSheetState extends State<MemoryCandidateReviewSheet> {
  int _currentIndex = 0;
  late TextEditingController _textController;
  late MemoryCategory _selectedCategory;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _initCurrent();
  }

  void _initCurrent() {
    if (widget.candidates.isNotEmpty && _currentIndex < widget.candidates.length) {
      final current = widget.candidates[_currentIndex];
      _textController = TextEditingController(text: current.factText);
      _selectedCategory = current.category;
    } else {
      _textController = TextEditingController();
      _selectedCategory = MemoryCategory.psychologicalComplaint;
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentIndex + 1 < widget.candidates.length) {
      setState(() {
        _currentIndex++;
        _isEditing = false;
        _initCurrent();
      });
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.candidates.isEmpty || _currentIndex >= widget.candidates.length) {
      return const SizedBox.shrink();
    }

    final candidate = widget.candidates[_currentIndex];

    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.psychology_outlined, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'EVA Ingin Mengingat Hal Ini',
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      'Item ${_currentIndex + 1} dari ${widget.candidates.length}',
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderSoft),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _selectedCategory.label,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(_isEditing ? Icons.check : Icons.edit_outlined, size: 20),
                      onPressed: () {
                        setState(() => _isEditing = !_isEditing);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_isEditing)
                  TextField(
                    controller: _textController,
                    maxLines: 3,
                    style: GoogleFonts.inter(fontSize: 14),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  )
                else
                  Text(
                    _textController.text,
                    style: GoogleFonts.inter(fontSize: 14, height: 1.5, color: const Color(0xFF1E293B)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    widget.onDecision(candidate, 'reject');
                    _next();
                  },
                  child: Text('Jangan Ingat', style: GoogleFonts.inter(color: AppColors.textSecondary)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    widget.onDecision(
                      candidate,
                      _isEditing ? 'edit' : 'accept',
                      editedText: _textController.text.trim(),
                      editedCategory: _selectedCategory,
                    );
                    _next();
                  },
                  child: Text(
                    'Simpan Memori',
                    style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
