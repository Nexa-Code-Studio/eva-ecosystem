import '../../../../core/network/api_client.dart';
import '../models/dass_assessment_model.dart';

abstract class DASSDataSource {
  Future<DASSAssessmentModel> getTodayAssessment();
  Future<DASSAssessmentModel> updateAssessment(List<Map<String, dynamic>> items);
  Future<DASSAssessmentModel> extractTodayAssessment();
}

class RemoteDASSDataSource implements DASSDataSource {
  final ApiClient _apiClient;

  RemoteDASSDataSource({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  @override
  Future<DASSAssessmentModel> getTodayAssessment() async {
    final response = await _apiClient.get('/dass/today');
    return DASSAssessmentModel.fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<DASSAssessmentModel> updateAssessment(List<Map<String, dynamic>> items) async {
    final response = await _apiClient.put(
      '/dass/today',
      body: {'items': items},
    );
    return DASSAssessmentModel.fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<DASSAssessmentModel> extractTodayAssessment() async {
    final response = await _apiClient.post('/dass/extract-today');
    return DASSAssessmentModel.fromJson(response as Map<String, dynamic>);
  }
}

class MockDASSDataSource implements DASSDataSource {
  DASSAssessmentModel _mockData = _generateInitialMock();

  static DASSAssessmentModel _generateInitialMock() {
    final defaultQuestions = [
      {'item_id': 1, 'scale': 'stress', 'text': 'Saya merasa bahwa diri saya menjadi marah karena hal-hal sepele.', 'score': 2, 'evidence': 'User: "Aku gampang marah sama hal-hal kecil"', 'reason': 'Pengguna mengungkapkan mudah terpancing marah oleh hal sepele dalam keseharian.', 'conf': 0.85},
      {'item_id': 2, 'scale': 'anxiety', 'text': 'Saya merasa bibir saya sering kering.', 'score': 0, 'evidence': null, 'reason': null, 'conf': 0.0},
      {'item_id': 3, 'scale': 'depression', 'text': 'Saya sama sekali tidak dapat merasakan perasaan positif.', 'score': 1, 'evidence': 'User: "Hari ini rasanya flat aja, nggak semangat"', 'reason': 'Pengguna menyatakan suasana hati datar dan kehilangan antusiasme beraktivitas.', 'conf': 0.70},
      {'item_id': 4, 'scale': 'anxiety', 'text': 'Saya mengalami kesulitan bernafas (misalnya : seringkali terengah-engah atau tidak dapat bernafas padahal tidak melakukan aktivitas fisik sebelumnya).', 'score': 0, 'evidence': null, 'reason': null, 'conf': 0.0},
      {'item_id': 5, 'scale': 'depression', 'text': 'Saya sepertinya tidak kuat lagi untuk melakukan suatu kegiatan.', 'score': 1, 'evidence': null, 'reason': null, 'conf': 0.0},
      {'item_id': 6, 'scale': 'stress', 'text': 'Saya cenderung bereaksi berlebihan terhadap suatu situasi.', 'score': 2, 'evidence': 'User: "Aku sering kebawa emosi berlebihan pas lagi capek"', 'reason': 'Pengguna merasakan sensitivitas emosional dan reaktivitas yang meningkat pada situasi harian.', 'conf': 0.80},
      {'item_id': 7, 'scale': 'anxiety', 'text': "Saya merasa goyah (misalnya : kaki terasa mau 'copot').", 'score': 0, 'evidence': null, 'reason': null, 'conf': 0.0},
      {'item_id': 8, 'scale': 'stress', 'text': 'Saya merasa sulit untuk bersantai.', 'score': 1, 'evidence': null, 'reason': null, 'conf': 0.0},
      {'item_id': 9, 'scale': 'anxiety', 'text': 'Saya menemukan diri saya berada dalam situasi yang membuat saya merasa sangat cemas dan saya akan merasa sangat lega jika semua ini berakhir.', 'score': 1, 'evidence': 'User: "Takut banget pas harus presentasi"', 'reason': 'Kecemasan situasional yang intens menjelang evaluasi publik.', 'conf': 0.75},
      {'item_id': 10, 'scale': 'depression', 'text': 'Saya merasa tidak ada hal yang dapat diharapkan di masa depan.', 'score': 0, 'evidence': null, 'reason': null, 'conf': 0.0},
      {'item_id': 11, 'scale': 'stress', 'text': 'Saya menemukan diri saya mudah merasa kesal.', 'score': 2, 'evidence': 'User: "Gelisah dan kesal mikirin deadline tugas"', 'reason': 'Pengguna menunjukkan ketegangan dan mudah kesal akibat tuntutan tugas.', 'conf': 0.88},
      {'item_id': 12, 'scale': 'stress', 'text': 'Saya merasa telah menghabiskan banyak energi untuk merasa cemas.', 'score': 2, 'evidence': null, 'reason': null, 'conf': 0.0},
      {'item_id': 13, 'scale': 'depression', 'text': 'Saya merasa sedih dan tertekan.', 'score': 1, 'evidence': 'User: "Sedih aja bawaannya"', 'reason': 'Suasana hati disforik atau rasa sedih yang menetap sepanjang hari.', 'conf': 0.65},
      {'item_id': 14, 'scale': 'stress', 'text': 'Saya menemukan diri saya menjadi tidak sabar ketika mengalami penundaan (misalnya : kemacetan lalu lintas, menunggu sesuatu).', 'score': 1, 'evidence': null, 'reason': null, 'conf': 0.0},
      {'item_id': 15, 'scale': 'anxiety', 'text': 'Saya merasa lemas seperti mau pingsan.', 'score': 0, 'evidence': null, 'reason': null, 'conf': 0.0},
      {'item_id': 16, 'scale': 'depression', 'text': 'Saya merasa saya kehilangan minat akan segala hal.', 'score': 1, 'evidence': null, 'reason': null, 'conf': 0.0},
      {'item_id': 17, 'scale': 'depression', 'text': 'Saya merasa bahwa saya tidak berharga sebagai seorang manusia.', 'score': 0, 'evidence': null, 'reason': null, 'conf': 0.0},
      {'item_id': 18, 'scale': 'stress', 'text': 'Saya merasa bahwa saya mudah tersinggung.', 'score': 1, 'evidence': null, 'reason': null, 'conf': 0.0},
      {'item_id': 19, 'scale': 'anxiety', 'text': 'Saya berkeringat secara berlebihan (misalnya : tangan berkeringat), padahal temperatur tidak panas atau tidak melakukan aktivitas fisik sebelumnya.', 'score': 1, 'evidence': 'User: "Tangan sampai keringat dingin tiba-tiba"', 'reason': 'Gejala otonomik berupa keringat berlebih yang disadari tanpa aktivitas fisik.', 'conf': 0.72},
      {'item_id': 20, 'scale': 'anxiety', 'text': 'Saya merasa takut tanpa alasan yang jelas.', 'score': 0, 'evidence': null, 'reason': null, 'conf': 0.0},
      {'item_id': 21, 'scale': 'depression', 'text': 'Saya merasa bahwa hidup tidak bermanfaat.', 'score': 0, 'evidence': null, 'reason': null, 'conf': 0.0},
    ];

    final items = defaultQuestions.map((q) {
      return DASSItemModel(
        itemId: q['item_id'] as int,
        scale: q['scale'] as String,
        questionText: q['text'] as String,
        score: q['score'] as int,
        evidence: q['evidence'] as String?,
        reason: q['reason'] as String?,
        confidence: (q['conf'] as num).toDouble(),
        isUserEdited: false,
      );
    }).toList();

    return DASSAssessmentModel(
      id: 'mock-dass-today',
      userId: 'mock-user-123',
      assessedDate: 'Hari Ini',
      depressionScore: 8, // (1+1+1+1)*2
      anxietyScore: 4,    // (1+1)*2
      stressScore: 22,    // (2+2+1+2+2+1+1)*2 = 22 -> Moderate
      depressionSeverity: 'Normal',
      anxietySeverity: 'Normal',
      stressSeverity: 'Moderate',
      verifiedByUser: false,
      status: 'auto_extracted',
      items: items,
    );
  }

  @override
  Future<DASSAssessmentModel> getTodayAssessment() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _mockData;
  }

  @override
  Future<DASSAssessmentModel> updateAssessment(List<Map<String, dynamic>> items) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final currentItems = List<DASSItemModel>.from(_mockData.items);
    final map = {for (var it in items) it['item_id'] as int: it['score'] as int};

    final updatedItems = currentItems.map((it) {
      if (map.containsKey(it.itemId)) {
        return DASSItemModel(
          itemId: it.itemId,
          scale: it.scale,
          questionText: it.questionText,
          score: map[it.itemId]!,
          evidence: it.evidence,
          reason: it.reason,
          confidence: it.confidence,
          isUserEdited: true,
        );
      }
      return it;
    }).toList();

    int depRaw = 0, anxRaw = 0, strRaw = 0;
    for (var it in updatedItems) {
      if (it.scale == 'depression') depRaw += it.score;
      if (it.scale == 'anxiety') anxRaw += it.score;
      if (it.scale == 'stress') strRaw += it.score;
    }

    final depScore = depRaw * 2;
    final anxScore = anxRaw * 2;
    final strScore = strRaw * 2;

    _mockData = DASSAssessmentModel(
      id: _mockData.id,
      userId: _mockData.userId,
      assessedDate: _mockData.assessedDate,
      depressionScore: depScore,
      anxietyScore: anxScore,
      stressScore: strScore,
      depressionSeverity: _calcSeverity('depression', depScore),
      anxietySeverity: _calcSeverity('anxiety', anxScore),
      stressSeverity: _calcSeverity('stress', strScore),
      verifiedByUser: true,
      status: 'verified',
      items: updatedItems,
    );

    return _mockData;
  }

  static String _calcSeverity(String scale, int score) {
    if (scale == 'depression') {
      if (score >= 28) return 'Extremely Severe';
      if (score >= 21) return 'Severe';
      if (score >= 14) return 'Moderate';
      if (score >= 10) return 'Mild';
      return 'Normal';
    } else if (scale == 'anxiety') {
      if (score >= 20) return 'Extremely Severe';
      if (score >= 15) return 'Severe';
      if (score >= 10) return 'Moderate';
      if (score >= 8) return 'Mild';
      return 'Normal';
    } else {
      if (score >= 34) return 'Extremely Severe';
      if (score >= 26) return 'Severe';
      if (score >= 19) return 'Moderate';
      if (score >= 15) return 'Mild';
      return 'Normal';
    }
  }

  @override
  Future<DASSAssessmentModel> extractTodayAssessment() async {
    return _mockData;
  }
}
