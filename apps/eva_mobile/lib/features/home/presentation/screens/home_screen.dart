import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:eva_mobile/config/app_config.dart';
import 'package:eva_mobile/features/auth/domain/entities/user_entity.dart';
import 'package:eva_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:eva_mobile/features/chat/domain/entities/conversation_entity.dart';
import 'package:eva_mobile/features/chat/presentation/providers/chat_provider.dart';
import 'package:eva_mobile/features/dass/domain/entities/dass_assessment_entity.dart';
import 'package:eva_mobile/features/dass/presentation/providers/dass_provider.dart';
import 'package:eva_mobile/features/diary/domain/entities/diary_entry_entity.dart';
import 'package:eva_mobile/features/diary/presentation/providers/diary_provider.dart';
import 'package:eva_mobile/features/home/presentation/widgets/home_activity_modal.dart';
import 'package:eva_mobile/features/home/presentation/widgets/home_daily_progress_card.dart';
import 'package:eva_mobile/features/home/presentation/widgets/home_eva_insight_card.dart';
import 'package:eva_mobile/features/home/presentation/widgets/home_quick_actions.dart';
import 'package:eva_mobile/features/home/presentation/widgets/home_recommendations_section.dart';
import 'package:eva_mobile/features/home/presentation/widgets/profile_dropdown_modal.dart';
import 'package:eva_mobile/features/recommendations/presentation/providers/recommendation_provider.dart';
import 'package:eva_mobile/providers/daily_progress_provider.dart';
import 'package:eva_mobile/services/daily_progress_local_service.dart';
import 'package:eva_mobile/theme/app_colors.dart';
import 'package:eva_mobile/widgets/app_snack_bar.dart';
import 'package:eva_mobile/widgets/staggered_entrance.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final ValueChanged<int>? onNavigateTab;

  const HomeScreen({
    super.key,
    this.onNavigateTab,
  });

  @override
  ConsumerState<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends ConsumerState<HomeScreen> with WidgetsBindingObserver {
  String _userName = 'Sahabat EVA';
  String _userEmail = 'samsul@gmail.com';
  int _todayConversationsCount = 0;

  String get _userInitials {
    final parts = _userName.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return 'SA';
  }
  bool _hasTodayDiary = false;
  String _aiInsight =
      'Setiap perasaan yang kamu alami hari ini adalah valid. Luangkan waktu sejenak untuk menarik napas dalam dan menyayangi dirimu sendiri.';

  DailyProgressData _localProgress = const DailyProgressData(date: '');
  bool _hasTodayDass = false;
  bool _dassVerifiedByUser = false;
  String _dassStatus = '';
  int _dassStressScore = 0;
  int _dassAnxietyScore = 0;
  int _dassDepressionScore = 0;
  String _targetCondition = 'general';
  String _conditionLabel = 'Fokus: Relaksasi & Perawatan Diri';
  String _conditionReason = 'Menjaga ritme emosi dan ketenangan pikiran harian';
  String _severityLevel = 'Normal';
  bool _isCrisis = false;
  String _crisisHotline = 'Kemenkes 119 ext 8 / LISA 0811-3855-472';
  String _crisisGuidance =
      'Keselamatan dan ketenanganmu adalah prioritas paling berharga. Silakan hubungi bantuan darurat bila beban terasa terlalu berat.';
  Map<String, dynamic>? _todayActivity;

  static final List<Map<String, dynamic>> _defaultRecommendations = [
    {
      'id': '1',
      'title': 'Latihan Pernapasan 4-7-8',
      'category': 'Mindfulness',
      'targetCondition': 'stress',
      'duration': '3 menit',
      'difficulty': 'Pemula',
      'description':
          'Tarik napas dalam 4 detik, tahan 7 detik, lalu hembuskan perlahan 8 detik untuk meredakan ketegangan sistem saraf.',
      'instructions': [
        'Duduk dengan nyaman dan punggung tegak.',
        'Tarik napas perlahan melalui hidung selama 4 detik.',
        'Tahan napasmu selama 7 detik.',
        'Hembuskan napas secara perlahan melalui mulut selama 8 detik.',
        'Ulangi siklus ini sebanyak 4 kali putaran.',
      ],
      'rationale':
          'Mengaktifkan respons relaksasi parasimpatik untuk menurunkan detak jantung dan meredakan ketegangan.',
      'isCompleted': false,
    },
    {
      'id': '2',
      'title': 'Teknik Grounding 5-4-3-2-1',
      'category': 'CBT',
      'targetCondition': 'anxiety',
      'duration': '5 menit',
      'difficulty': 'Pemula',
      'description':
          'Sadarilah 5 hal yang kamu lihat, 4 hal yang kamu sentuh, 3 suara di sekitarmu, 2 aroma, dan 1 rasa untuk kembali ke saat ini.',
      'instructions': [
        'Sebutkan 5 hal yang bisa kamu lihat di sekitarmu.',
        'Sentuh dan rasakan 4 benda yang ada di dekatmu.',
        'Dengarkan secara saksama 3 suara berbeda di ruangan ini.',
        'Identifikasi 2 aroma yang tercium olehmu saat ini.',
        'Fokuskan lidahmu pada 1 rasa yang masih tertinggal di mulutmu.',
      ],
      'rationale':
          'Mengalihkan fokus otak dari lingkaran kecemasan ke persepsi sensorik nyata saat ini.',
      'isCompleted': false,
    },
    {
      'id': '3',
      'title': 'Catatan Syukur Harian',
      'category': 'Refleksi',
      'targetCondition': 'depression',
      'duration': '3 menit',
      'difficulty': 'Pemula',
      'description':
          'Tuliskan satu hal sederhana yang memberimu kehangatan atau kenyamanan hari ini.',
      'instructions': [
        'Tarik napas dalam sejenak dan pejamkan matamu perlahan.',
        'Ingat satu momen kecil yang membuatmu merasa hangat atau tersenyum hari ini.',
        'Tuliskan secara spesifik apa momen itu dan mengapa itu berarti bagimu.',
      ],
      'rationale':
          'Melatih otak mengenali afek positif dan memutus kecenderungan bias negatif.',
      'isCompleted': false,
    },
  ];

  late List<Map<String, dynamic>> _recommendations;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _recommendations = List<Map<String, dynamic>>.from(
      _defaultRecommendations.map((item) => Map<String, dynamic>.from(item)),
    );
    _loadHomeScreenData();
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
    _loadHomeScreenData();
    ref.read(dailyProgressProvider.notifier).refresh();
  }

  Future<void> _loadHomeScreenData() async {
    // 1. Load cached user info first for instant display
    final cachedName = await AppConfig.getUserName();
    final cachedEmail = await AppConfig.getUserEmail();
    if (cachedName != null && cachedName.isNotEmpty && mounted) {
      setState(() => _userName = cachedName);
    }
    if (cachedEmail != null && cachedEmail.isNotEmpty && mounted) {
      _userEmail = cachedEmail;
    }

    // 2. Load today's local self-care progress (auto-reset if new day)
    final localData = await DailyProgressLocalService.loadTodayProgress();
    if (mounted) {
      setState(() => _localProgress = localData);
    }

    try {
      final results = await Future.wait([
        // 0: Profile
        ref.read(authRepositoryProvider).getCurrentUser().catchError((_) => null),
        // 1: Today conversations
        ref.read(chatRepositoryProvider).getConversations().catchError((_) => <ConversationEntity>[]),
        // 2: Today diary & emotions
        ref.read(diaryRepositoryProvider).getTodayDiary().catchError((_) => null),
        // 3: Tailored recommendation for today
        ref.read(recommendationRepositoryProvider).getTodayRecommendation().catchError((_) => <String, dynamic>{}),
        // 4: Today DASS-21 assessment
        ref.read(dassRepositoryProvider).getTodayAssessment().then<DASSAssessmentEntity?>((a) => a).catchError((_) => null),
      ]);

      if (!mounted) return;

      // Handle Profile
      final user = results[0] as UserEntity?;
      if (user != null) {
        _userName = user.name;
        if (user.email.isNotEmpty) {
          _userEmail = user.email;
        }
      }

      // Handle Today Conversations
      final conversations = results[1] as List<ConversationEntity>? ?? [];
      _todayConversationsCount = conversations.length;
      if (_todayConversationsCount > 0) {
        _localProgress = await DailyProgressLocalService.recordConversationCheckin(
          hasConversation: true,
        );
      }

      // Handle Today Diary
      final diary = results[2] as DiaryEntryEntity?;
      if (diary != null) {
        _hasTodayDiary = true;
        _localProgress = await DailyProgressLocalService.recordDiaryCheckin(
          hasDiary: true,
        );
        if (diary.aiInsight.isNotEmpty) {
          _aiInsight = diary.aiInsight;
        }
      }

      // Handle Today Tailored Recommendation
      final recData = results[3] as Map<String, dynamic>? ?? {};
      if (recData['todayActivity'] != null) {
        _targetCondition = recData['targetCondition']?.toString() ?? 'general';
        _conditionLabel =
            recData['conditionLabel']?.toString() ?? 'Fokus: Relaksasi & Perawatan Diri';
        _conditionReason = recData['conditionReason']?.toString() ?? '';
        _severityLevel = recData['severityLevel']?.toString() ?? 'Normal';
        _isCrisis = recData['isCrisis'] == true;
        if (recData['crisisHotline'] != null) {
          _crisisHotline = recData['crisisHotline'].toString();
        }
        if (recData['crisisGuidance'] != null) {
          _crisisGuidance = recData['crisisGuidance'].toString();
        }

        final act = recData['todayActivity'] as Map<String, dynamic>;
        final actId = act['id']?.toString() ?? '';
        final bool isActDone = act['isCompleted'] == true ||
            _localProgress.isActivityCompleted(actId);

        final actMap = {
          'id': actId,
          'title': act['title']?.toString() ?? 'Latihan Relaksasi',
          'category': act['category']?.toString() ?? 'Self-Care',
          'targetCondition':
              act['targetCondition']?.toString() ?? _targetCondition,
          'duration': act['duration']?.toString() ?? '5 menit',
          'difficulty': act['difficulty']?.toString() ?? 'Pemula',
          'description': act['description']?.toString() ?? '',
          'instructions': act['instructions'] is List
              ? List<String>.from(
                  act['instructions'].map((e) => e.toString()))
              : <String>[],
          'rationale': act['rationale']?.toString() ?? '',
          'iconName': act['iconName']?.toString() ?? 'spa',
          'isCompleted': isActDone,
        };

        _todayActivity = actMap;

        final List<Map<String, dynamic>> combined = [actMap];
        if (recData['alternatives'] is List) {
          for (var item in recData['alternatives']) {
            final altId = item['id']?.toString() ?? '';
            combined.add({
              'id': altId,
              'title': item['title']?.toString() ?? 'Rekomendasi',
              'category': item['category']?.toString() ?? 'Self-Care',
              'targetCondition':
                  item['targetCondition']?.toString() ?? _targetCondition,
              'duration': item['duration']?.toString() ?? '5 menit',
              'difficulty': item['difficulty']?.toString() ?? 'Pemula',
              'description': item['description']?.toString() ?? '',
              'instructions': <String>[],
              'rationale': '',
              'isCompleted': item['isCompleted'] == true ||
                  _localProgress.isActivityCompleted(altId),
            });
          }
        }
        _recommendations = combined;

        if (isActDone && !_localProgress.isActivityCompleted(actId)) {
          _localProgress =
              await DailyProgressLocalService.recordActivityCompletion(
            actId,
            true,
          );
        }
      }

      // Handle Today DASS-21 Assessment
      final dass = results[4] as DASSAssessmentEntity?;
      if (dass != null) {
        _hasTodayDass = dass.id?.isNotEmpty == true;
        _dassVerifiedByUser = dass.verifiedByUser;
        _dassStatus = dass.status;
        _dassStressScore = dass.stressScore;
        _dassAnxietyScore = dass.anxietyScore;
        _dassDepressionScore = dass.depressionScore;
      }
    } catch (_) {}

    if (mounted) setState(() {});
  }

  Future<void> _toggleRecommendationComplete(String id) async {
    bool currentStatus = false;
    final idx = _recommendations.indexWhere((r) => r['id'] == id);
    if (idx != -1) {
      currentStatus = _recommendations[idx]['isCompleted'] == true;
      setState(() {
        _recommendations[idx]['isCompleted'] = !currentStatus;
      });
    }

    if (_todayActivity != null && _todayActivity!['id'] == id) {
      currentStatus = _todayActivity!['isCompleted'] == true;
      setState(() {
        _todayActivity!['isCompleted'] = !currentStatus;
      });
    }

    final newStatus = !currentStatus;

    final updatedProgress =
        await DailyProgressLocalService.recordActivityCompletion(
      id,
      newStatus,
    );
    if (mounted) {
      setState(() {
        _localProgress = updatedProgress;
      });
    }

    if (newStatus) {
      try {
        await ref.read(recommendationRepositoryProvider).markAsCompleted(id);
      } catch (_) {}
    }
  }

  int get _completedRoutinesCount {
    int count = 0;
    if (_localProgress.hasConversation || _todayConversationsCount > 0) count++;
    if (_localProgress.hasDiary || _hasTodayDiary) count++;
    final bool activityDone = _localProgress.completedActivityIds.isNotEmpty ||
        (_todayActivity != null && _todayActivity!['isCompleted'] == true) ||
        _recommendations.any((r) => r['isCompleted'] == true);
    if (activityDone) count++;
    return count;
  }

  void _showProfileDropdown(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'ProfileDropdown',
      barrierColor: Colors.black.withValues(alpha: 0.3),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (dialogContext, anim1, anim2) {
        return SafeArea(
          child: Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.only(top: 50.0, right: 20.0),
              child: Material(
                color: Colors.transparent,
                child: ProfileDropdownModal(
                  userName: _userName,
                  userEmail: _userEmail,
                  onProfileTap: () {
                    Navigator.pop(dialogContext);
                    Navigator.pushNamed(context, '/user_profile').then((_) {
                      if (mounted) _loadHomeScreenData();
                    });
                  },
                  onEmergencyContactsTap: () {
                    Navigator.pop(dialogContext);
                    Navigator.pushNamed(context, '/emergency_contacts');
                  },
                  onSettingsTap: () {
                    Navigator.pop(dialogContext);
                    Navigator.pushNamed(context, '/settings');
                  },
                  onCoinTap: () {
                    Navigator.pop(dialogContext);
                    Navigator.pushNamed(context, '/coin_purchase');
                  },
                  onLogoutTap: () async {
                    Navigator.pop(dialogContext);
                    await AppConfig.clearToken();
                    if (context.mounted) {
                      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                    }
                  },
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (dialogContext, anim1, anim2, child) {
        final curved = CurvedAnimation(parent: anim1, curve: Curves.easeOutBack);
        return ScaleTransition(
          alignment: Alignment.topRight,
          scale: Tween<double>(begin: 0.85, end: 1.0).animate(curved),
          child: FadeTransition(
            opacity: anim1,
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final liveProgress = ref.watch(dailyProgressProvider);
    _localProgress = liveProgress;

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
            onRefresh: _loadHomeScreenData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 110.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User Greeting Header with Space Between & Profile Photo
                  StaggeredEntrance(
                    index: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Halo, $_userName! 👋',
                                style: GoogleFonts.inter(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Bagaimana perasaanmu hari ini?',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () => _showProfileDropdown(context),
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [Color(0xFF8B93FF), Color(0xFF5358CB)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.25),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: Center(
                              child: Text(
                                _userInitials,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Empathetic AI Psychologist Insight Card
                  StaggeredEntrance(
                    index: 2,
                    child: HomeEvaInsightCard(insightText: _aiInsight),
                  ),
                  const SizedBox(height: 20),

                  // Quick Navigation Shortcuts
                  StaggeredEntrance(
                    index: 3,
                    child: HomeQuickActions(
                      onTapChat: () async {
                        await Navigator.pushNamed(context, '/chat');
                        refresh();
                      },
                      onTapDiary: () async {
                        if (widget.onNavigateTab != null) {
                          widget.onNavigateTab!(1);
                        } else {
                          await Navigator.pushNamed(context, '/diary');
                          refresh();
                        }
                      },
                      onTapDass: () async {
                        await Navigator.pushNamed(context, '/dass_assessment');
                        refresh();
                      },
                      dassSubtitle: _dassVerifiedByUser
                          ? 'Stres: $_dassStressScore • Cemas: $_dassAnxietyScore • Depresi: $_dassDepressionScore'
                          : (_hasTodayDass && _dassStatus == 'auto_extracted'
                              ? 'Tersintesis AI • Ketuk untuk meninjau'
                              : 'Evaluasi & koreksi 21 butir emosi'),
                      showDassNotificationDot: _hasTodayDass &&
                          _dassStatus == 'auto_extracted' &&
                          !_dassVerifiedByUser,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Evidence-Based Daily Progress Section (3 Pillars)
                  StaggeredEntrance(
                    index: 4,
                    child: HomeDailyProgressCard(
                      completedCount: _completedRoutinesCount,
                      isConversationDone:
                          _localProgress.hasConversation || _todayConversationsCount > 0,
                      isDiaryDone: _localProgress.hasDiary || _hasTodayDiary,
                      isExerciseDone: _localProgress.completedActivityIds.isNotEmpty ||
                          (_todayActivity != null &&
                              _todayActivity!['isCompleted'] == true) ||
                          _recommendations.any((r) => r['isCompleted'] == true),
                      todayConversationsCount: _todayConversationsCount,
                      onTapConversation: () async {
                        await Navigator.pushNamed(context, '/chat');
                        refresh();
                      },
                      onTapDiary: () async {
                        if (widget.onNavigateTab != null) {
                          widget.onNavigateTab!(1);
                        } else {
                          await Navigator.pushNamed(context, '/diary');
                          refresh();
                        }
                      },
                      onTapExercise: () async {
                        await Navigator.pushNamed(context, '/recommendation');
                        refresh();
                      },
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Latest Clinically-Informed Recommendation
                  StaggeredEntrance(
                    index: 5,
                    child: _buildLatestRecommendationSection(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLatestRecommendationSection() {
    final Map<String, dynamic> activeRec = (_todayActivity != null &&
            _todayActivity!["isCompleted"] != true)
        ? _todayActivity!
        : (_recommendations.isNotEmpty
            ? _recommendations.firstWhere(
                (r) => r["isCompleted"] != true,
                orElse: () => _todayActivity ?? _recommendations.first,
              )
            : _defaultRecommendations.first);

    final id = activeRec["id"]?.toString() ?? "1";
    final isDone = activeRec["isCompleted"] == true ||
        _localProgress.isActivityCompleted(id);

    return HomeRecommendationsSection(
      activeRec: activeRec,
      conditionLabel: _conditionLabel,
      severityLevel: _severityLevel,
      isCrisis: _isCrisis,
      crisisGuidance: _crisisGuidance,
      crisisHotline: _crisisHotline,
      isDone: isDone,
      onSeeAll: () async {
        await Navigator.pushNamed(context, "/recommendation");
        _loadHomeScreenData();
      },
      onSupportTap: () {
        Navigator.pushNamed(context, "/support");
      },
      onOpenDetail: () => _showActivityDetailModal(context, activeRec),
      onToggleComplete: (toggleId) => _toggleRecommendationComplete(toggleId),
    );
  }

  void _showActivityDetailModal(
      BuildContext context, Map<String, dynamic> activity) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final id = activity['id']?.toString() ?? '';
        final isDone = (_todayActivity != null && _todayActivity!['id'] == id)
            ? (_todayActivity!['isCompleted'] == true)
            : _localProgress.isActivityCompleted(id);

        return HomeActivityModalContent(
          activity: activity,
          conditionReason: _conditionReason,
          isCompleted: isDone,
          onComplete: () async {
            if (isDone) {
              AppSnackBar.showPrimary(
                context,
                'Kamu sudah menyelesaikan latihan ini hari ini! Kerja bagus, istirahatlah sejenak dan lanjutkan kembali besok 🌿',
                icon: Icons.info_outline,
              );
              Navigator.pop(ctx);
              return;
            }
            await _toggleRecommendationComplete(id);
            if (context.mounted) {
              AppSnackBar.showSuccess(
                context,
                'Bagus sekali! Satu langkah kecil untuk ketenanganmu telah selesai.',
                icon: Icons.check_circle,
              );
              Navigator.pop(ctx);
            }
          },
        );
      },
    );
  }
}
