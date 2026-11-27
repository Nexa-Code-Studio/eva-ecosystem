import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eva_mobile/features/coping/catalog/coping_catalog_page.dart';
import 'package:eva_mobile/features/coping/exercises/breathing/breathing.dart';
import 'package:eva_mobile/features/coping/exercises/breathing/presentation/painters/breathing_human_painter.dart';
import 'package:eva_mobile/features/coping/exercises/breathing/presentation/painters/breathing_ring_painter.dart';
import 'package:eva_mobile/features/coping/exercises/breathing/presentation/widgets/breathing_visual_stage.dart';
import 'package:eva_mobile/features/coping/shared/domain/coping_session_result.dart';
import 'package:eva_mobile/features/coping/shared/presentation/coping_guidance_sheet.dart';
import 'package:eva_mobile/features/recommendations/domain/entities/recommendation_entity.dart';
import 'package:eva_mobile/features/recommendations/domain/repositories/recommendation_repository.dart';
import 'package:eva_mobile/features/recommendations/presentation/providers/recommendation_provider.dart';
import 'package:eva_mobile/features/recommendations/presentation/screens/recommendation_screen.dart';
import 'package:eva_mobile/features/recommendations/presentation/widgets/guidance_modal_content.dart';
import 'package:eva_mobile/widgets/floating_nav_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _EmptyAssetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    throw FlutterError('Asset $key not bundled');
  }
}

class _MockRecommendationRepo implements RecommendationRepository {
  @override
  Future<List<RecommendationEntity>> getRecommendations() async => const [];

  @override
  Future<Map<String, dynamic>> getTodayRecommendation() async => {
    'conditionLabel': 'Fokus: Relaksasi',
    'conditionReason': 'Membantu menenangkan pikiran hari ini',
    'severityLevel': 'Normal',
    'isCrisis': false,
    'todayActivity': {
      'id': 'c1',
      'title': 'Latihan Pernapasan 4-7-8',
      'category': 'Mindfulness',
      'duration': '3-5 Menit',
      'difficulty': 'Pemula',
      'description': 'Atur napas perlahan untuk meredakan ketegangan.',
      'instructions': [
        'Duduk nyaman dan rileks.',
        'Ikuti panduan tarikan dan hembusan napas di layar.',
      ],
      'rationale': 'Membantu aktivasi saraf parasimpatik.',
      'isCompleted': false,
    },
    'allRecommendations': [
      {
        'id': 'c2',
        'title': 'Teknik Grounding 5-4-3-2-1',
        'category': 'CBT',
        'duration': '5 Menit',
        'difficulty': 'Pemula',
        'description': 'Kenali 5 hal di sekitarmu.',
        'instructions': ['Lihat 5 benda di sekitar.', 'Sentuh 4 tekstur.'],
        'rationale': 'Mengembalikan fokus ke saat ini.',
        'isCompleted': false,
      },
    ],
  };

  @override
  Future<void> markAsCompleted(String id) async {}
}

void main() {
  group('BreathingExperiencePage Widget, Accessibility & Navigation', () {
    testWidgets(
      'renders immersive session without bottom nav bar, supports pause/resume, tap ripple, and returns cancelled on exit',
      (tester) async {
        tester.view.physicalSize = const Size(412, 915);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        CopingSessionResult? poppedResult;

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Builder(
                builder: (context) => Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () async {
                        poppedResult = await Navigator.of(context).push(
                          MaterialPageRoute<CopingSessionResult>(
                            builder: (_) => const BreathingExperiencePage(
                              forceVisualOnly: true,
                            ),
                          ),
                        );
                      },
                      child: const Text('Launch Breathing'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Launch Breathing'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // Immersive route hides bottom navigation bar and keeps header uncluttered.
        expect(find.byType(FloatingNavBar), findsNothing);
        expect(find.text('Mode Visual'), findsNothing);
        expect(find.byType(CustomPaint), findsWidgets);

        // Verify our ring and human painters are in the tree.
        final painters = tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .map((w) => w.painter.runtimeType)
            .toSet();
        expect(painters.contains(BreathingRingPainter), isTrue);
        expect(painters.contains(BreathingHumanPainter), isTrue);

        // Tap center canvas to spawn optional touch ripple without blocking controls.
        await tester.tapAt(const Offset(206, 420));
        await tester.pump(const Duration(milliseconds: 100));

        // Pause and verify pause banner/instruction update cleanly.
        final pauseBtn = find.byKey(const Key('breathing_play_pause_button'));
        expect(pauseBtn, findsOneWidget);
        await tester.tap(pauseBtn);
        await tester.pump(const Duration(milliseconds: 200));
        expect(
          find.text('Latihan dijeda. Ketuk Lanjutkan saat kamu siap.'),
          findsOneWidget,
        );

        // Resume cleanly.
        await tester.tap(pauseBtn);
        await tester.pump(const Duration(milliseconds: 200));

        // Exit early returns cancelled outcome, never completed.
        await tester.tap(find.byKey(const Key('breathing_exit_button')));
        await tester.pumpAndSettle();

        expect(poppedResult, isNotNull);
        expect(poppedResult!.status, CopingSessionStatus.cancelled);
        expect(poppedResult!.isCompleted, isFalse);
      },
    );

    testWidgets(
      'renders cleanly without overflow at narrow viewport, large 2.0 text scaling, and reduced motion',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(
                  size: Size(320, 568),
                  disableAnimations: true,
                  textScaler: TextScaler.linear(2.0),
                ),
                child: BreathingExperiencePage(forceVisualOnly: true),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'navigates from CopingCatalogPage to immersive breathing exercise and back',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              routes: {
                BreathingExerciseModule.routeName: (_) =>
                    const BreathingExperiencePage(forceVisualOnly: true),
              },
              home: const CopingCatalogPage(),
            ),
          ),
        );

        expect(find.text('Latihan Pernapasan Terpandu'), findsOneWidget);
        await tester.tap(find.text('Latihan Pernapasan Terpandu'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.byType(BreathingExperiencePage), findsOneWidget);

        await tester.tap(find.byKey(const Key('breathing_exit_button')));
        await tester.pumpAndSettle();

        expect(find.byType(CopingCatalogPage), findsOneWidget);
      },
    );

    testWidgets(
      'GuidanceModalContent launches BreathingExperiencePage and ignores early cancellation',
      (tester) async {
        var completed = false;
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: GuidanceModalContent(
                  actId: 'c1',
                  title: 'Latihan Pernapasan 4-7-8',
                  category: 'Ketenangan',
                  duration: '3 Menit',
                  difficulty: 'Mudah',
                  description: 'Menenangkan sistem saraf.',
                  rationale: 'Membantu ritme napas melambat.',
                  instructions: const ['Duduk nyaman', 'Ikuti panduan layar'],
                  isBreathingActivity: true,
                  isCompleted: false,
                  onComplete: () => completed = true,
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Mulai Sesi'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 450));

        expect(find.byType(BreathingExperiencePage), findsOneWidget);

        await tester.tap(find.byKey(const Key('breathing_exit_button')));
        await tester.pumpAndSettle();

        expect(completed, isFalse);
        expect(find.byType(GuidanceModalContent), findsOneWidget);
      },
    );

    testWidgets(
      'BreathingVisualStage paints phase updates without errors across inhale and exhale frames',
      (tester) async {
        final motion = ValueNotifier<BreathingMotionFrame>(
          const BreathingMotionFrame(
            positionMs: 5000,
            phase: BreathingPhase.inhale,
            phaseProgress: 0.25,
            breathAmount: 0.25,
            lungScale: 1.05,
            glowIntensity: 0.65,
            sessionProgress: 0.125,
            phaseRemainingSeconds: 3,
          ),
        );
        addTearDown(motion.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 390,
                height: 844,
                child: BreathingVisualStage(
                  motion: motion,
                  reducedMotion: false,
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        motion.value = const BreathingMotionFrame(
          positionMs: 10000,
          phase: BreathingPhase.exhale,
          phaseProgress: 0.5,
          breathAmount: 0.5,
          lungScale: 1.1,
          glowIntensity: 0.5,
          sessionProgress: 0.25,
          phaseRemainingSeconds: 2,
        );
        await tester.pump();

        motion.value = const BreathingMotionFrame(
          positionMs: 12000,
          phase: BreathingPhase.exhale,
          phaseProgress: 1.0,
          breathAmount: 0.0,
          lungScale: 1.0,
          glowIntensity: 0.25,
          sessionProgress: 0.30,
          phaseRemainingSeconds: 0,
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Panduan Ketenangan opens new breathing page with tutorial modal before starting session',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = const Size(412, 915);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              recommendationRepositoryProvider.overrideWithValue(
                _MockRecommendationRepo(),
              ),
              breathingTimelineLoaderProvider.overrideWithValue(
                BreathingTimelineLoader(bundle: _EmptyAssetBundle()),
              ),
            ],
            child: const MaterialApp(home: RecommendationScreen()),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('FOKUS: RELAKSASI'), findsNothing);
        expect(find.text('Level: Normal'), findsNothing);
        expect(find.text('Aktivitas Utama Hari Ini'), findsOneWidget);

        // Tapping hero CTA opens BreathingExperiencePage first, then tutorial modal.
        await tester.tap(find.text('Buka Panduan Langkah'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 450));

        expect(find.byType(BreathingExperiencePage), findsOneWidget);
        expect(find.text('Kenapa Latihan Ini Membantu?'), findsOneWidget);
        expect(
          find.byKey(const Key('coping_tutorial_start_button')),
          findsOneWidget,
        );
        // Session controls wait until user taps Mulai Sesi inside tutorial modal.
        expect(
          find.byKey(const Key('breathing_play_pause_button')),
          findsNothing,
        );

        // Dismissing tutorial cancels cleanly back to Panduan Ketenangan.
        await tester.tap(find.byKey(const Key('coping_tutorial_close_button')));
        await tester.pumpAndSettle();
        expect(find.byType(RecommendationScreen), findsOneWidget);

        // Re-open and start session via tutorial modal CTA.
        await tester.tap(find.text('Buka Panduan Langkah'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 450));
        await tester.tap(find.byKey(const Key('coping_tutorial_start_button')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pump(const Duration(milliseconds: 200));

        expect(
          find.byKey(const Key('breathing_play_pause_button')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Panduan Ketenangan non-breathing item opens step page with tutorial modal then gamified steps',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = const Size(412, 915);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              recommendationRepositoryProvider.overrideWithValue(
                _MockRecommendationRepo(),
              ),
              breathingTimelineLoaderProvider.overrideWithValue(
                BreathingTimelineLoader(bundle: _EmptyAssetBundle()),
              ),
            ],
            child: const MaterialApp(home: RecommendationScreen()),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.ensureVisible(find.text('Teknik Grounding 5-4-3-2-1'));
        await tester.tap(find.text('Teknik Grounding 5-4-3-2-1'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 450));

        expect(find.byType(CopingStepExercisePage), findsOneWidget);
        expect(
          find.byKey(const Key('coping_tutorial_start_button')),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const Key('coping_tutorial_start_button')));
        await tester.pumpAndSettle();

        expect(find.text('Langkah 1/2'), findsOneWidget);
        expect(
          find.byKey(const Key('coping_step_next_button')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('coping_step_next_button')));
        await tester.pumpAndSettle();
        expect(find.text('Langkah 2/2'), findsOneWidget);

        await tester.tap(find.byKey(const Key('coping_step_next_button')));
        await tester.pumpAndSettle();
        expect(find.byType(RecommendationScreen), findsOneWidget);
      },
    );
  });
}
