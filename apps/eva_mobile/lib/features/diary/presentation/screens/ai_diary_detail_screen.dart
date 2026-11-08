import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../theme/app_colors.dart';
import '../../../../widgets/app_back_button.dart';
import '../../../../widgets/staggered_entrance.dart';
import '../../../chat/presentation/providers/chat_provider.dart';
import '../../data/models/diary_entry_model.dart';
import '../../data/datasources/diary_fallback_fixture.dart';
import '../providers/diary_provider.dart';
import '../widgets/diary_emotion_distribution_card.dart';
import '../widgets/diary_insight_card.dart';
import '../widgets/diary_key_events_card.dart';
import '../widgets/diary_reflection_card.dart';
import '../widgets/diary_transcript_section.dart';

/// Screen displaying comprehensive AI-synthesized diary details, cumulative daily insights,
/// session breakdowns, emotional reflections, and voice transcripts.
class AiDiaryDetailScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? journalData;

  const AiDiaryDetailScreen({
    super.key,
    this.journalData,
  });

  @override
  ConsumerState<AiDiaryDetailScreen> createState() => _AiDiaryDetailScreenState();
}

class _AiDiaryDetailScreenState extends ConsumerState<AiDiaryDetailScreen> {
  late String _selectedSessionId;
  bool _isInitialized = false;
  Map<String, dynamic>? _diaryData;

  // Streaming and Skeleton State
  bool _isStreaming = false;
  bool _isLoadingSkeleton = false;
  bool _streamError = false;
  String? _streamedSummary;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      final args = widget.journalData ??
          (ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?);
      if (args != null) {
        _diaryData = Map<String, dynamic>.from(args);
        _selectedSessionId = args['selectedSessionId']?.toString() ?? 'all';

        final bool isSingle = _diaryData!['isSingleSession'] == true;
        final dId = _diaryData!['id'];

        if (isSingle) {
          final convId = _diaryData!['conversationId'] ?? dId;
          final existingSummary = _diaryData!['summary'];
          if (existingSummary == null || existingSummary.toString().trim().isEmpty) {
            if (convId != null) {
              _streamSummary(convId.toString());
            }
          } else {
            _streamedSummary = existingSummary.toString();
          }
        } else if (dId != null) {
          _fetchDiaryDetail(dId.toString());
        }
      } else {
        _selectedSessionId = 'all';
      }
      _isInitialized = true;
    }
  }

  Future<void> _streamSummary(String conversationId) async {
    if (_isStreaming) return;

    setState(() {
      _isLoadingSkeleton = true;
      _isStreaming = true;
      _streamError = false;
      _streamedSummary = null;
    });

    try {
      final stream = ref.read(chatRepositoryProvider).streamConversationSummary(conversationId);
      await for (final token in stream) {
        if (!mounted) break;
        setState(() {
          _isLoadingSkeleton = false;
          _streamedSummary = (_streamedSummary ?? '') + token;
        });
      }
      if (mounted) {
        setState(() {
          _isStreaming = false;
          _isLoadingSkeleton = false;
          if (_diaryData != null && _streamedSummary != null) {
            _diaryData!['summary'] = _streamedSummary;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isStreaming = false;
          _isLoadingSkeleton = false;
          _streamError = true;
        });
      }
    }
  }

  Future<void> _fetchDiaryDetail(String diaryId) async {
    try {
      final repository = ref.read(diaryRepositoryProvider);
      final entry = await repository.getDiaryEntryById(diaryId);
      if (entry != null && mounted) {
        setState(() {
          if (entry is DiaryEntryModel) {
            _diaryData = entry.toJson();
          } else {
            _diaryData = {
              'id': entry.id,
              'title': entry.title,
              'date': entry.date,
              'sessionCount': entry.sessionCount,
              'lastSessionTime': entry.lastSessionTime,
              'moodTag': entry.moodTag,
              'moodEmoji': entry.moodEmoji,
              'summary': entry.summary,
              'aiInsight': entry.aiInsight,
              'importantEvents': entry.importantEvents,
              'emotionalReflection': entry.emotionalReflection,
              'sessions': entry.sessions.map((s) => {
                'id': s.id,
                'title': s.title,
                'time': s.time,
                'moodTag': s.moodTag,
                'moodEmoji': s.moodEmoji,
              }).toList(),
            };
          }
        });
      }
    } catch (_) {
      // Graceful fallback to existing passed state or default fixture
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = widget.journalData ??
        (ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?);

    final data = _diaryData ?? args ?? kDefaultDiaryDetailFallback;
    final bool isSingleSession = data['isSingleSession'] == true;
    final bool hasRisk = data['riskWarning'] != null && data['riskWarning']['detected'] == true;

    final List<dynamic> rawEvents =
        data['importantEvents'] is List ? data['importantEvents'] as List : [];
    final List<String> importantEvents = rawEvents.isNotEmpty
        ? rawEvents.map((e) => e.toString()).toList()
        : ['Sesi refleksi harian tercatat dalam sistem EVA.'];

    final List<Map<String, dynamic>> sessions =
        (data['sessions'] is List && (data['sessions'] as List).isNotEmpty)
            ? (data['sessions'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList()
            : [];

    if (_selectedSessionId != 'all' && sessions.isNotEmpty) {
      final exists = sessions.any((s) => s['id'].toString() == _selectedSessionId);
      if (!exists) {
        _selectedSessionId = 'all';
      }
    }

    // Compute active emotions breakdown based on selected session
    List<Map<String, dynamic>> activeEmotions = [];
    if (_selectedSessionId == 'all') {
      if (data['emotionsBreakdown'] is List && (data['emotionsBreakdown'] as List).isNotEmpty) {
        activeEmotions = (data['emotionsBreakdown'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      } else {
        activeEmotions = [
          {'name': 'fear', 'label': 'Takut / Gelisah', 'emoji': '😨', 'percent': 0.45, 'color': const Color(0xFF6C63FF)},
          {'name': 'sadness', 'label': 'Sedih / Haru', 'emoji': '😔', 'percent': 0.25, 'color': const Color(0xFF8B93FF)},
          {'name': 'netral', 'label': 'Netral', 'emoji': '😐', 'percent': 0.15, 'color': const Color(0xFFA7E6FF)},
          {'name': 'happy', 'label': 'Bahagia', 'emoji': '😃', 'percent': 0.10, 'color': const Color(0xFFFFE6A7)},
          {'name': 'surprise', 'label': 'Terkejut', 'emoji': '😲', 'percent': 0.03, 'color': const Color(0xFFC3B8FF)},
          {'name': 'anger', 'label': 'Marah', 'emoji': '😡', 'percent': 0.01, 'color': const Color(0xFFFFB6C1)},
          {'name': 'disgusted', 'label': 'Jijik / Muak', 'emoji': '🤢', 'percent': 0.01, 'color': const Color(0xFFB8C2FC)},
        ];
      }
    } else {
      Map<String, dynamic>? selectedSessData;
      for (var s in sessions) {
        if (s['id'].toString() == _selectedSessionId) {
          selectedSessData = s;
          break;
        }
      }
      if (selectedSessData == null && sessions.isNotEmpty) {
        selectedSessData = sessions.first;
      }

      if (selectedSessData != null &&
          selectedSessData['emotionsBreakdown'] is List &&
          (selectedSessData['emotionsBreakdown'] as List).isNotEmpty) {
        activeEmotions = (selectedSessData['emotionsBreakdown'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      } else {
        activeEmotions = [
          {'name': 'netral', 'label': 'Ketenangan & Refleksi', 'emoji': '😌', 'percent': 0.60, 'color': const Color(0xFFA7E6FF)},
          {'name': 'happy', 'label': 'Lega & Nyaman', 'emoji': '😃', 'percent': 0.40, 'color': const Color(0xFFFFE6A7)},
        ];
      }
    }

    // Compute active transcripts list based on selected session
    List<Map<String, dynamic>> activeTranscripts = [];
    if (_selectedSessionId == 'all') {
      for (var s in sessions) {
        final rawTrans = s['transcripts'];
        if (rawTrans is List) {
          activeTranscripts.addAll(
            rawTrans.map((t) => Map<String, dynamic>.from(t as Map)),
          );
        }
      }
    } else {
      for (var s in sessions) {
        if (s['id'].toString() == _selectedSessionId) {
          final rawTrans = s['transcripts'];
          if (rawTrans is List) {
            activeTranscripts.addAll(
              rawTrans.map((t) => Map<String, dynamic>.from(t as Map)),
            );
          }
          break;
        }
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9FB),
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  const AppBackButton(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['title']?.toString() ?? 'Detail Jurnal Refleksi',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isSingleSession
                              ? '${data['date'] ?? 'Hari ini'} • ${data['moodTag'] ?? 'Tenang & Nyaman'}'
                              : '${data['date'] ?? 'Hari ini'} • ${sessions.length} Sesi Suara',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
            ),
            const Divider(height: 1, color: Color(0xFFEBECEF)),

            // Main Body Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // MENTAL HEALTH ALERT CARD (If Risk Detected)
                    if (hasRisk) ...[
                      StaggeredEntrance(
                        index: 1,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF0F2),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: const Color(0xFFE57373).withValues(alpha: 0.4),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFE57373).withValues(alpha: 0.1),
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
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE57373),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.crisis_alert, color: Colors.white, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      data['riskWarning']['title']?.toString() ??
                                          'Indikasi Distress Terdeteksi',
                                      style: GoogleFonts.inter(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFFC62828),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                data['riskWarning']['message']?.toString() ??
                                    'Pola emosi kumulatif menunjukkan beban emosional yang tinggi.',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: AppColors.textPrimary,
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // 1. WAWASAN AI KUMULATIF / RINGKASAN SESI
                    DiaryInsightCard(
                      isSingleSession: isSingleSession,
                      sessionCount: sessions.length,
                      lastSessionTime: data['lastSessionTime']?.toString(),
                      isLoadingSkeleton: _isLoadingSkeleton,
                      isStreaming: _isStreaming,
                      streamError: _streamError,
                      streamedSummary: _streamedSummary,
                      summaryText: (isSingleSession
                              ? (_streamedSummary ?? data['summary'] ?? data['aiInsight'])
                              : data['aiInsight'])
                          ?.toString(),
                      onRetry: () {
                        final convId = data['conversationId'] ?? data['id'];
                        if (convId != null) {
                          _streamSummary(convId.toString());
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    if (!isSingleSession) ...[
                      StaggeredEntrance(
                        index: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 2. PERISTIWA PENTING KUMULATIF
                            DiaryKeyEventsCard(events: importantEvents),
                            const SizedBox(height: 16),

                            // 3. REFLEKSI EMOSIONAL
                            DiaryReflectionCard(
                              reflectionText: data['emotionalReflection']?.toString(),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ],

                    StaggeredEntrance(
                      index: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // SESSION SELECTOR CHIPS SECTION
                          if (!isSingleSession && sessions.isNotEmpty) ...[
                            Text(
                              'PILIH SESI UNTUK PENGURAIAN SPESIFIK',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textLight,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 46,
                              child: ListView(
                                clipBehavior: Clip.none,
                                padding: const EdgeInsets.symmetric(vertical: 3),
                                scrollDirection: Axis.horizontal,
                                children: [
                                  ChoiceChip(
                                    showCheckmark: false,
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                    label: Text('Semua Sesi (${sessions.length})'),
                                    selected: _selectedSessionId == 'all',
                                    selectedColor: AppColors.primaryContainer,
                                    backgroundColor: Colors.white.withValues(alpha: 0.9),
                                    labelStyle: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: _selectedSessionId == 'all'
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: _selectedSessionId == 'all'
                                          ? AppColors.primary
                                          : AppColors.textSecondary,
                                    ),
                                    onSelected: (_) => setState(() => _selectedSessionId = 'all'),
                                  ),
                                  const SizedBox(width: 8),
                                  ...sessions.map((sess) {
                                    final sId = sess['id']?.toString() ?? '';
                                    final isSel = _selectedSessionId == sId;
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 8.0),
                                      child: ChoiceChip(
                                        showCheckmark: false,
                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        visualDensity: VisualDensity.compact,
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                        label: Text(sess['title']?.toString() ?? 'Sesi'),
                                        selected: isSel,
                                        selectedColor: AppColors.primaryContainer,
                                        backgroundColor: Colors.white.withValues(alpha: 0.9),
                                        labelStyle: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                                          color: isSel ? AppColors.primary : AppColors.textSecondary,
                                        ),
                                        onSelected: (_) => setState(() => _selectedSessionId = sId),
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],

                          // 4. ANALISIS EMOSI PER SESI (7 Parameter Emosi Filtered)
                          DiaryEmotionDistributionCard(
                            activeEmotions: activeEmotions,
                            isSingleSession: isSingleSession,
                            selectedSessionId: _selectedSessionId,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 5. TRANSKRIP PERCAKAPAN SUARA
                    DiaryTranscriptSection(
                      transcripts: activeTranscripts,
                      isSingleSession: isSingleSession,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
