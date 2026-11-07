import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:eva_mobile/features/chat/presentation/widgets/animated_session_card.dart';
import 'package:eva_mobile/features/chat/presentation/widgets/session_list_skeleton.dart';
import 'package:eva_mobile/theme/app_colors.dart';
import 'package:eva_mobile/widgets/app_back_button.dart';
import 'package:eva_mobile/widgets/custom_button.dart';
import 'package:eva_mobile/widgets/glass_card.dart';
import 'package:eva_mobile/widgets/staggered_entrance.dart';
import '../providers/chat_provider.dart';

class AiConversationScreen extends ConsumerStatefulWidget {
  const AiConversationScreen({super.key});

  @override
  ConsumerState<AiConversationScreen> createState() => _AiConversationScreenState();
}

class _AiConversationScreenState extends ConsumerState<AiConversationScreen> {
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _conversations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchConversations(isRefresh: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchConversations({bool isRefresh = false}) async {
    if (isRefresh) {
      setState(() => _isLoading = true);
    }

    try {
      final entities = await ref.read(chatRepositoryProvider).getConversations();
      final items = entities.map((c) => <String, dynamic>{
        'id': c.id,
        'title': c.title,
        'date': c.date,
        'lastMessageTime': c.lastSessionTime,
        'dominant_emoji': c.moodEmoji,
        'dominant_emotion': c.moodTag,
        'summary': c.summary,
        'messages': c.messages.map((m) => <String, dynamic>{
          'id': m.id,
          'sender': m.isUser ? 'user' : 'ai',
          'text': m.text,
          'time': m.time,
          'emotionEmoji': m.emotionEmoji,
        }).toList(),
      }).toList();

      if (mounted) {
        setState(() => _conversations = items);
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  static ({String tag, String emoji}) _detectEmotionFallback(String text) {
    final tLow = text.toLowerCase();
    const anxWords = ['cemas', 'takut', 'nervous', 'panggung', 'khawatir', 'panik', 'deg-degan', 'gugup', 'takutnya', 'bingung', 'was-was', 'tegang'];
    const depWords = ['sedih', 'nangis', 'menangis', 'hampa', 'sendiri', 'kehilangan', 'terpuruk', 'putus asa', 'kecewa', 'patah hati', 'bunuh diri'];
    const strWords = ['stres', 'capek', 'lelah', 'beban', 'berat', 'penat', 'pusing', 'mumet', 'tekanan', 'tugas', 'deadline', 'kerjaan', 'letih'];
    const angWords = ['marah', 'kesal', 'jengkel', 'benci', 'emosi', 'sebal', 'kesel', 'geram', 'murka'];
    const posWords = ['lega', 'senang', 'bahagia', 'terima kasih', 'makasih', 'enakan', 'tenang', 'nyaman', 'santai', 'alhamdulillah', 'syukurlah', 'baik', 'bersyukur'];

    if (anxWords.any((w) => tLow.contains(w))) {
      return (tag: 'fear (78%)', emoji: '😨');
    }
    if (depWords.any((w) => tLow.contains(w))) {
      return (tag: 'sadness (82%)', emoji: '😔');
    }
    if (strWords.any((w) => tLow.contains(w))) {
      return (tag: 'stress (75%)', emoji: '💥');
    }
    if (angWords.any((w) => tLow.contains(w))) {
      return (tag: 'anger (70%)', emoji: '😡');
    }
    if (posWords.any((w) => tLow.contains(w))) {
      return (tag: 'calm (85%)', emoji: '😌');
    }
    return (tag: 'netral (60%)', emoji: '😐');
  }

  @override
  Widget build(BuildContext context) {

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

          child: Column(

            children: [

              // Header Bar

              Padding(

                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),

                child: Row(

                  children: [

                    const AppBackButton(),
                    const SizedBox(width: 10),

                    Image.asset(

                      'assets/images/eva_logo.png',

                      width: 32,

                      height: 32,

                      fit: BoxFit.contain,

                      errorBuilder: (context, error, stackTrace) {

                        return const Icon(

                          Icons.nightlight_round,

                          size: 28,

                          color: AppColors.primary,

                        );

                      },

                    ),

                    const SizedBox(width: 8),

                    Text(

                      'Sesi Suara EVA',

                      style: GoogleFonts.inter(

                        fontSize: 16,

                        fontWeight: FontWeight.w700,

                        color: AppColors.primary,

                      ),

                    ),

                  ],

                ),

              ),

              const Divider(height: 1, color: Color(0xFFEBECEF)),



              // Scrollable Content Body with Pull-to-Refresh & Infinite Scroll
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () => _fetchConversations(isRefresh: true),
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                    child: Column(

                    children: [

                      const SizedBox(height: 12),



                      // 3D Glowing Iridescent Orb Visual
                      StaggeredEntrance(
                        index: 0,
                        child: Center(
                          child: Container(
                            width: 180,
                            height: 180,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const SweepGradient(
                                colors: [
                                  Color(0xFFFFB6C1),
                                  Color(0xFFE2DAFF),
                                  Color(0xFFA7E6FF),
                                  Color(0xFF8B93FF),
                                  Color(0xFFFFB6C1),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.3),
                                  blurRadius: 40,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                            child: Container(
                              margin: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    Colors.white,
                                    Color(0xFFEADBFF),
                                    Color(0xFFA7E6FF),
                                  ],
                                  center: Alignment(-0.3, -0.3),
                                  radius: 0.8,
                                ),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.graphic_eq,
                                  size: 48,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Title & Subtitle Greeting
                      StaggeredEntrance(
                        index: 1,
                        child: Column(
                          children: [
                            Text(
                              'EVA Siap Mendengarkan',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              child: Text(
                                'Bicara secara alami kapan saja tanpa mengetik. EVA hadir mendampingi dan mendengarkan perasaanmu.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: AppColors.textSecondary,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Main Action Button: Mulai Sesi Suara
                      StaggeredEntrance(
                        index: 2,
                        child: CustomPillButton(
                          text: 'Mulai Sesi Suara',
                          suffixIcon: Icons.mic,
                          onPressed: () async {
                            await Navigator.pushNamed(context, '/voice_call');
                            if (mounted) {
                              _fetchConversations(isRefresh: true);
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 36),

                      // Recent Voice Sessions Section
                      StaggeredEntrance(
                        index: 3,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'RIWAYAT SESI SUARA TERAKHIR',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textLight,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 350),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        child: _isLoading
                            ? const SessionListSkeleton(key: ValueKey('session_skeleton_list'))
                            : _conversations.isNotEmpty
                                ? Column(
                                    key: const ValueKey('session_conversation_list'),
                                    children: [
                                      for (int i = 0; i < _conversations.length; i++)
                                        AnimatedSessionCard(
                                          key: ValueKey('session_card_${_conversations[i]['id'] ?? i}'),
                                          index: i,
                                          child: Padding(
                                            padding: const EdgeInsets.only(bottom: 10),
                                            child: _buildSessionCard(context, _conversations[i]),
                                          ),
                                        ),
                                    ],
                                  )
                                : Padding(
                                    key: const ValueKey('session_empty_list'),
                                    padding: const EdgeInsets.symmetric(vertical: 36.0, horizontal: 16.0),
                                    child: Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.forum_outlined, size: 44, color: AppColors.textLight),
                                          const SizedBox(height: 12),
                                          Text(
                                            'Belum ada riwayat sesi suara',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Mulai panggilan suara bersama EVA untuk menyimpan sesi percakapanmu.',
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 12,
                                              color: AppColors.textLight,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                      ),
                      const SizedBox(height: 24),
                    ],
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

  Widget _buildSessionCard(BuildContext context, Map<String, dynamic> conv) {
    final title = conv['title']?.toString() ?? 'Sesi Percakapan EVA';
    final time = conv['lastMessageTime']?.toString() ?? 'Hari ini';
    final msgs = conv['messages'] as List? ?? [];
    final duration = (conv['duration'] != null && conv['duration'].toString().isNotEmpty)
        ? conv['duration'].toString()
        : '00:00';

    String dominantEmoji = conv['dominant_emoji']?.toString() ?? '';
    String dominantEmotion = conv['dominant_emotion']?.toString() ?? '';
    if (dominantEmoji.isEmpty) {
      for (final m in msgs) {
        if (m is Map && m['sender'] == 'user') {
          final emoji = (m['emotionEmoji'] ?? m['emotion_emoji'])?.toString();
          if (emoji != null && emoji.isNotEmpty) {
            dominantEmoji = emoji;
            break;
          }
          final text = (m['text'] ?? '').toString();
          if (text.isNotEmpty) {
            dominantEmoji = _detectEmotionFallback(text).emoji;
            break;
          }
        }
      }
    }
    if (dominantEmoji.isEmpty) dominantEmoji = '😌';
    if (dominantEmotion.isEmpty) dominantEmotion = 'Tenang & Nyaman';

    return _buildSessionHistoryCard(
      title: title,
      duration: duration,
      date: time,
      dominantEmoji: dominantEmoji,
      onTap: () {
        Navigator.pushNamed(
          context,
          '/diary_detail',
          arguments: {
            'id': conv['id'],
            'conversationId': conv['id'],
            'title': title,
            'date': time,
            'isSingleSession': true,
            'sessionCount': 1,
            'lastSessionTime': time,
            'moodTag': dominantEmotion,
            'moodEmoji': dominantEmoji,
            'summary': conv['summary'],
            'riskWarning': {'detected': false},
            'aiInsight': conv['summary'] ??
                'Percakapan berhasil disintesis dan diproses untuk pemantauan kesehatan emosionalmu.',
            'importantEvents': ['Sesi percakapan aktif selesai tercatat'],
            'emotionalReflection':
                'Emosi terartikulasi secara positif melalui sesi curhat bersama AI.',
            'sessions': [
              {
                'id': conv['id'] ?? 's1',
                'title': title,
                'time': time,
                'moodTag': dominantEmotion,
                'moodEmoji': dominantEmoji,
                'emotionsBreakdown': [
                  {
                    'name': 'netral',
                    'label': 'Netral',
                    'emoji': '😐',
                    'percent': 0.60,
                    'color': const Color(0xFFA7E6FF)
                  },
                  {
                    'name': 'happy',
                    'label': 'Lega',
                    'emoji': '😌',
                    'percent': 0.40,
                    'color': const Color(0xFFFFE6A7)
                  },
                ],
                'transcripts': msgs
                    .map((m) {
                      final isUser = m['sender'] == 'user';
                      final text = (m['text'] ?? '').toString();
                      final tag = (m['emotionTag'] ?? m['emotion_tag'])?.toString();
                      final emoji = (m['emotionEmoji'] ?? m['emotion_emoji'])?.toString();

                      String resolvedTag = '';
                      String resolvedEmoji = '';
                      if (isUser) {
                        if (tag != null && tag.isNotEmpty && tag != 'Refleksi') {
                          resolvedTag = tag;
                          resolvedEmoji = (emoji != null && emoji.isNotEmpty) ? emoji : '🌱';
                        } else {
                          final fallback = _detectEmotionFallback(text);
                          resolvedTag = fallback.tag;
                          resolvedEmoji = fallback.emoji;
                        }
                      }

                      return {
                        'isUser': isUser,
                        'time': m['time'] ?? '',
                        'text': text,
                        'emotionTag': resolvedTag,
                        'emotionEmoji': resolvedEmoji,
                      };
                    })
                    .toList(),
              }
            ],
            'selectedSessionId': conv['id'] ?? 's1',
          },
        );
      },
    );
  }

  Widget _buildSessionHistoryCard({
    required String title,
    required String duration,
    required String date,
    required String dominantEmoji,
    required VoidCallback onTap,
  }) {
    return GlassCard(
      width: double.infinity,
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Text(
              dominantEmoji,
              style: const TextStyle(fontSize: 22),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$date • $duration',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textLight,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.chevron_right,
            color: AppColors.textLight,
            size: 20,
          ),
        ],
      ),
    );
  }
}
