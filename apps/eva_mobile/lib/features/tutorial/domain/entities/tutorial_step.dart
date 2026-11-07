enum TutorialStep {
  voiceSession,
  journal,
  analytics,
  care,
}

enum SpotlightShape {
  circle,
  roundedRectangle,
}

enum PointerDirection {
  up,
  down,
  none,
}

class TutorialContent {
  final String title;
  final String description;
  final String? actionHint;
  final String badgeText;
  final SpotlightShape shape;
  final PointerDirection pointerDirection;
  final bool isInteractiveTarget;

  const TutorialContent({
    required this.title,
    required this.description,
    this.actionHint,
    this.badgeText = 'LUNA AI',
    this.shape = SpotlightShape.circle,
    this.pointerDirection = PointerDirection.down,
    this.isInteractiveTarget = true,
  });

  static const Map<TutorialStep, TutorialContent> stepContents = {
    TutorialStep.voiceSession: TutorialContent(
      title: 'Cerita ke Luna, yuk!',
      description:
          'Tekan tombol tengah untuk mulai berbicara. Kamu bisa mulai saat sudah siap.',
      actionHint: 'Ketuk tombol di bawah untuk mencoba',
      badgeText: 'REKOMENDASI LUNA',
      shape: SpotlightShape.circle,
      pointerDirection: PointerDirection.down,
      isInteractiveTarget: true,
    ),
    TutorialStep.journal: TutorialContent(
      title: 'Jurnal Refleksi Otomatis',
      description:
          'Setiap selesai bercerita, intisari perasaan dan renunganmu otomatis tersusun rapi di sini secara privat.',
      actionHint: 'Buka kapan saja untuk membaca catatanmu',
      badgeText: 'JURNAL AI',
      shape: SpotlightShape.roundedRectangle,
      pointerDirection: PointerDirection.down,
      isInteractiveTarget: false,
    ),
    TutorialStep.analytics: TutorialContent(
      title: 'Tren Emosi & DASS-21',
      description:
          'AI merangkum indikator suasana hatimu otomatis. Kamu memiliki kendali penuh untuk menyesuaikan nilainya secara mandiri.',
      actionHint: 'Pantau kesehatan emosimu berkala',
      badgeText: 'ANALITIK DASS',
      shape: SpotlightShape.roundedRectangle,
      pointerDirection: PointerDirection.down,
      isInteractiveTarget: false,
    ),
    TutorialStep.care: TutorialContent(
      title: 'Layanan & Dukungan Sebaya',
      description:
          'Jika butuh teman bicara manusia, temukan konseling profesional dan volunteer terpercaya di sini.',
      actionHint: 'Bantuan selalu tersedia untukmu',
      badgeText: 'LAYANAN CARE',
      shape: SpotlightShape.roundedRectangle,
      pointerDirection: PointerDirection.down,
      isInteractiveTarget: false,
    ),
  };
}
