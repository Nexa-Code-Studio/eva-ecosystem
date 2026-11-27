import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../theme/app_colors.dart';
import '../../../../widgets/app_back_button.dart';
import '../../../../widgets/staggered_entrance.dart';
import '../../../chat/presentation/providers/chat_provider.dart';
import '../../../monitoring/presentation/providers/monitoring_provider.dart';
import '../../../voice_call/presentation/providers/ai_call_provider.dart';
import '../../data/models/diary_entry_model.dart';
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
          final existingSummary = _diaryData!['summary']?.toString().trim() ?? '';
          final sessionsList = _diaryData!['sessions'] as List?;
          final firstEmotions = (sessionsList != null && sessionsList.isNotEmpty && sessionsList.first is Map)
              ? (sessionsList.first['emotionsBreakdown'] as List?)
              : null;
          final needsSynthesis = existingSummary.isEmpty ||
              existingSummary.startsWith('User:') ||
              (firstEmotions == null || firstEmotions.isEmpty);

          if (!needsSynthesis) {
            _streamedSummary = existingSummary;
          } else if (convId != null) {
            _streamSummary(convId.toString());
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
      final synthesisService = ref.read(statelessSynthesisServiceProvider);
      final isDone = await synthesisService.isSessionSynthesized(conversationId);
      if (!isDone) {
        final ok = await synthesisService.synthesizeSessionOnDemand(sessionId: conversationId);
        if (ok && mounted) {
          final updatedConv = await ref.read(chatRepositoryProvider).getConversationById(conversationId);
          if (updatedConv != null && mounted) {
            setState(() {
              _isLoadingSkeleton = false;
              _isStreaming = false;
              _streamedSummary = updatedConv.summary;
              if (_diaryData != null) {
                _diaryData!['title'] = updatedConv.title;
                _diaryData!['moodTag'] = updatedConv.moodTag;
                _diaryData!['moodEmoji'] = updatedConv.moodEmoji;
                _diaryData!['summary'] = updatedConv.summary;
                final sessions = _diaryData!['sessions'];
                if (sessions is List && sessions.isNotEmpty && sessions.first is Map) {
                  final firstSess = Map<String, dynamic>.from(sessions.first as Map);
                  firstSess['title'] = updatedConv.title;
                  firstSess['moodTag'] = updatedConv.moodTag;
                  firstSess['moodEmoji'] = updatedConv.moodEmoji;
                  firstSess['emotionsBreakdown'] = updatedConv.emotionsBreakdown;
                  if (updatedConv.messages.isNotEmpty) {
                    firstSess['transcripts'] = updatedConv.messages
                        .map((m) => {
                              'isUser': m.isUser,
                              'time': m.time,
                              'text': m.text,
                              'emotionTag': m.emotionTag ?? '',
                              'emotionEmoji': m.emotionEmoji ?? '',
                            })
                        .toList();
                  }
                  _diaryData!['sessions'] = [firstSess];
                }
              }
            });
            ref.invalidate(conversationsProvider);
            ref.invalidate(diaryEntriesProvider);
            ref.invalidate(monitoringDataProvider);
            return;
          }
        }
      }

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
          if (_diaryData != null && _streamedSummary != null && _streamedSummary!.isNotEmpty) {
            _diaryData!['summary'] = _streamedSummary;
          } else if (_streamedSummary == null || _streamedSummary!.isEmpty) {
            _streamError = true;
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
                'transcripts': s.transcripts,
                'emotionsBreakdown': s.emotionsBreakdown,
              }).toList(),
            };
          }
        });
        _attemptLazyOnDemandSynthesis(entry);
      }
    } catch (_) {
      // Graceful fallback to existing passed state or default fixture
    }
  }

  Future<void> _attemptLazyOnDemandSynthesis(dynamic entry) async {
    try {
      final synthesisService = ref.read(statelessSynthesisServiceProvider);
      for (final s in entry.sessions) {
        final sId = s.id?.toString();
        if (sId != null && sId.isNotEmpty) {
          final isDone = await synthesisService.isSessionSynthesized(sId);
          if (!isDone) {
            final ok = await synthesisService.synthesizeSessionOnDemand(sessionId: sId);
            if (ok && mounted) {
              final repo = ref.read(diaryRepositoryProvider);
              final refreshed = await repo.getDiaryEntryById(entry.id.toString());
              if (refreshed != null && mounted) {
                setState(() {
                  _diaryData = (refreshed is DiaryEntryModel) ? refreshed.toJson() : _diaryData;
                });
                ref.invalidate(diaryEntriesProvider);
                ref.invalidate(monitoringDataProvider);
              }
            }
          }
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final args = widget.journalData ??
        (ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?);

    final data = _diaryData ?? args;
    if (data == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF9F9FB),
        body: SafeArea(
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Row(
                  children: [
                    AppBackButton(),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    'Data jurnal atau sesi tidak tersedia.',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
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
        // Collect and aggregate real emotion distributions from all sessions
        final Map<String, double> aggregatedScores = {};
        final Map<String, Map<String, dynamic>> metaMap = {};

        for (var s in sessions) {
          final sBreakdown = s['emotionsBreakdown'];
          if (sBreakdown is List && sBreakdown.isNotEmpty) {
            for (var item in sBreakdown) {
              if (item is Map) {
                final name = item['name']?.toString() ?? 'netral';
                final pct = (item['percent'] as num?)?.toDouble() ?? 0.0;
                aggregatedScores[name] = (aggregatedScores[name] ?? 0.0) + pct;
                metaMap[name] = Map<String, dynamic>.from(item);
              }
            }
          }
        }

        if (aggregatedScores.isNotEmpty) {
          final total = aggregatedScores.values.fold(0.0, (a, b) => a + b);
          activeEmotions = aggregatedScores.entries.map((entry) {
            final meta = metaMap[entry.key] ?? {};
            return {
              'name': entry.key,
              'label': meta['label'] ?? entry.key,
              'emoji': meta['emoji'] ?? '✨',
              'percent': total > 0 ? (entry.value / total) : 0.0,
              'color': meta['color'] ?? const Color(0xFFA7E6FF),
            };
          }).toList();
          activeEmotions.sort((a, b) => ((b['percent'] as num?) ?? 0.0).compareTo((a['percent'] as num?) ?? 0.0));
        }
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
      }
    }

    // Compute active transcripts list based on selected session
    List<Map<String, dynamic>> activeTranscripts = [];
    if (_selectedSessionId == 'all') {
      final seenTransKeys = <String>{};
      for (var s in sessions) {
        final rawTrans = s['transcripts'];
        if (rawTrans is List) {
          for (var t in rawTrans) {
            if (t is Map) {
              final map = Map<String, dynamic>.from(t);
              final text = map['text']?.toString().trim() ?? '';
              final role = map['role']?.toString() ?? (map['isUser'] == true ? 'user' : 'assistant');
              final key = '$role:$text';
              if (text.isNotEmpty && !seenTransKeys.contains(key)) {
                seenTransKeys.add(key);
                activeTranscripts.add(map);
              }
            }
          }
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
