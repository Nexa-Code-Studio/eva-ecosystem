enum TutorialStep {
  voiceSession,
  voiceCoins,
  voiceStart,
  voiceCompleted,
  journal,
  analytics,
  dassDetail,
  dassItem,
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
  final String nextButtonLabel;

  const TutorialContent({
    required this.title,
    required this.description,
    this.actionHint,
    this.badgeText = 'EVA AI',
    this.shape = SpotlightShape.circle,
    this.pointerDirection = PointerDirection.down,
    this.isInteractiveTarget = true,
    this.nextButtonLabel = 'Lanjut',
  });

  static const Map<TutorialStep, TutorialContent> stepContents = {
    TutorialStep.voiceSession: TutorialContent(
      title: 'Cerita ke Eva, yuk!',
      description:
          'Tekan tombol tengah untuk mulai berbicara. Kamu bisa mulai saat sudah siap.',
      actionHint: 'Ketuk tombol di bawah untuk mencoba',
      badgeText: 'REKOMENDASI EVA',
      shape: SpotlightShape.circle,
      pointerDirection: PointerDirection.down,
      isInteractiveTarget: true,
    ),
    TutorialStep.voiceCoins: TutorialContent(
      title: 'Telepon Pakai Koin',
      description:
          'Setiap sesi suara bersama Eva menggunakan koin. Pantau saldo atau isi ulang koinmu kapan saja di sini.',
      actionHint: 'Ketuk koin atau tombol Lanjut',
      badgeText: 'INFO KOIN',
      shape: SpotlightShape.roundedRectangle,
      pointerDirection: PointerDirection.up,
      isInteractiveTarget: false,
    ),
    TutorialStep.voiceStart: TutorialContent(
      title: 'Mulai Sesi Suara',
      description:
          'Tekan tombol Mulai Sesi Suara untuk memulai percakapan langsung dan mencurahkan perasaanmu kepada Eva.',
      actionHint: 'Ketuk Mulai Sesi Suara',
      badgeText: 'SESI SUARA',
      shape: SpotlightShape.roundedRectangle,
      pointerDirection: PointerDirection.down,
      isInteractiveTarget: true,
    ),
    TutorialStep.voiceCompleted: TutorialContent(
      title: 'Refleksi Sesi Suara',
      description:
          'Sesi suaramu telah tersimpan. Buka jurnal refleksi untuk melihat intisari emosi dan renungan harianmu.',
      actionHint: 'Ketuk Lihat Detail Jurnal Refleksi',
      badgeText: 'REFLEKSI AI',
      shape: SpotlightShape.roundedRectangle,
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
      title: 'Lembar Evaluasi DASS-21',
      description:
          'AI merangkum indikator Stres, Cemas, dan Depresi secara otomatis. Ketuk untuk meninjau asesmenmu hari ini.',
      actionHint: 'Ketuk Tinjau Asesmen Hari Ini atau Lanjut',
      badgeText: 'ANALITIK DASS',
      shape: SpotlightShape.roundedRectangle,
      pointerDirection: PointerDirection.down,
      isInteractiveTarget: false,
    ),
    TutorialStep.dassDetail: TutorialContent(
      title: 'Tinjauan Indikator DASS-21',
      description:
          'Di sini kamu dapat melihat skor klinis dan evaluasi suasana hatimu. Kamu memiliki kendali penuh untuk meninjau secara mandiri.',
      actionHint: 'Ketuk Lanjut untuk melihat butir evaluasi',
      badgeText: 'PENJELASAN DASS',
      shape: SpotlightShape.roundedRectangle,
      pointerDirection: PointerDirection.down,
      isInteractiveTarget: false,
    ),
    TutorialStep.dassItem: TutorialContent(
      title: 'Hasil Ekstraksi Otomatis AI',
      description:
          'EVA otomatis mendeteksi butir ini dari percakapanmu. Jika skornya dirasa kurang pas, kamu bebas menggeser atau mengubahnya secara manual.',
      actionHint: 'Ketuk Lanjut untuk melihat layanan bantuan',
      badgeText: 'EKSTRAKSI AI',
      shape: SpotlightShape.roundedRectangle,
      pointerDirection: PointerDirection.down,
      isInteractiveTarget: false,
    ),
    TutorialStep.care: TutorialContent(
      title: 'Layanan & Dukungan Sebaya',
      description:
          'Jika butuh teman bicara manusia, temukan konseling profesional dan volunteer terpercaya di sini.',
      actionHint: 'Bantuan selalu tersedia di menu Layanan',
      badgeText: 'LAYANAN CARE',
      shape: SpotlightShape.roundedRectangle,
      pointerDirection: PointerDirection.down,
      isInteractiveTarget: false,
      nextButtonLabel: 'Selesai',
    ),
  };
}
