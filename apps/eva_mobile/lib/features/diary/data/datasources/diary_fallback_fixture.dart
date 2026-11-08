import 'package:flutter/material.dart';

/// Fallback mock dataset for AI Diary Detail screen when no arguments or data are provided.
final Map<String, dynamic> kDefaultDiaryDetailFallback = {
  'title': 'Refleksi Harian & Evaluasi Ujian',
  'date': '24 Oktober 2023',
  'sessionCount': 3,
  'lastSessionTime': '21:45 PM',
  'moodTag': 'Cemas & Stres',
  'moodEmoji': '😰',
  'summary':
      'Kumulatif 3 sesi suara hari ini: Refleksi Pagi (kecemasan akademik), Curhat Sore (istirahat teh), dan Refleksi Malam (evaluasi jadwal). EVA menyintesis kemajuan emosional harianmu.',
  'riskWarning': {
    'detected': true,
    'type': 'anxiety',
    'title': 'Indikasi Anxiety & Stres Kumulatif Terdeteksi',
    'level': 'Tinggi (68%)',
    'message':
        'EVA mendeteksi akumulasi kecemasan dan stres pada 3 sesi percakapan hari ini. Jangan ragu mengambil waktu jeda istirahat.',
  },
  'aiInsight':
      'Kumulatif Hari Ini: Meskipun beban akademik memicu akumulasi rasa cemas pada Sesi #1 dan Sesi #3, kamu berhasil menenangkan diri pada Sesi #2 saat istirahat teh.',
  'importantEvents': [
    '[Sesi #1 - 09:15 AM] Sesi belajar pagi & kecemasan ujian tengah semester',
    '[Sesi #2 - 16:30 PM] Minum teh hangat & jeda santai',
    '[Sesi #3 - 21:45 PM] Mengatur ulang target jadwal perkuliahan',
  ],
  'emotionalReflection':
      'Dinamika harian menunjukkan fluktuasi dari kecemasan tinggi di pagi hari, mereda di sore hari, dan kembali reflektif di malam hari.',
  'sessions': [
    {
      'id': 's1',
      'title': 'Sesi #1: Refleksi Pagi & Ujian',
      'time': '09:15 AM',
      'moodTag': 'Takut & Cemas',
      'moodEmoji': '😨',
      'emotionsBreakdown': [
        {'name': 'fear', 'label': 'Takut / Gelisah', 'emoji': '😨', 'percent': 0.65, 'color': const Color(0xFF6C63FF)},
        {'name': 'sadness', 'label': 'Sedih / Haru', 'emoji': '😔', 'percent': 0.20, 'color': const Color(0xFF8B93FF)},
        {'name': 'netral', 'label': 'Netral', 'emoji': '😐', 'percent': 0.15, 'color': const Color(0xFFA7E6FF)},
      ],
      'transcripts': [
        {
          'isUser': true,
          'time': '09:15 AM',
          'text': 'Saya sangat cemas dan takut tidak bisa menyelesaikan tugas kuliah ini dengan baik.',
          'emotionTag': 'fear (68%)',
          'emotionEmoji': '😨',
        },
        {
          'isUser': false,
          'time': '09:16 AM',
          'text':
              'Aku mendengarmu, Sarah. Sangat wajar merasa cemas saat tugas menumpuk. Mari kita uraikan bersama menjadi langkah kecil ya.',
        },
      ],
    },
    {
      'id': 's2',
      'title': 'Sesi #2: Jeda Ketenangan Sore',
      'time': '16:30 PM',
      'moodTag': 'Tenang & Nyaman',
      'moodEmoji': '😌',
      'emotionsBreakdown': [
        {'name': 'netral', 'label': 'Netral', 'emoji': '😐', 'percent': 0.50, 'color': const Color(0xFFA7E6FF)},
        {'name': 'happy', 'label': 'Bahagia', 'emoji': '😃', 'percent': 0.35, 'color': const Color(0xFFFFE6A7)},
        {'name': 'fear', 'label': 'Takut / Gelisah', 'emoji': '😨', 'percent': 0.15, 'color': const Color(0xFF6C63FF)},
      ],
      'transcripts': [
        {
          'isUser': true,
          'time': '16:30 PM',
          'text': 'Saya baru saja minum teh dan berjalan santai sebentar. Rasanya sedikit lebih lega.',
          'emotionTag': 'netral (60%)',
          'emotionEmoji': '😐',
        },
        {
          'isUser': false,
          'time': '16:31 PM',
          'text':
              'Itu langkah yang luar biasa! Memberikan waktu istirahat pada pikiran sangat penting untuk pemulihan energimu.',
        },
      ],
    },
    {
      'id': 's3',
      'title': 'Sesi #3: Evaluasi Malam & Jadwal',
      'time': '21:45 PM',
      'moodTag': 'Reflektif & Lelah',
      'moodEmoji': '😴',
      'emotionsBreakdown': [
        {'name': 'fear', 'label': 'Takut / Gelisah', 'emoji': '😨', 'percent': 0.40, 'color': const Color(0xFF6C63FF)},
        {'name': 'sadness', 'label': 'Sedih / Haru', 'emoji': '😔', 'percent': 0.35, 'color': const Color(0xFF8B93FF)},
        {'name': 'netral', 'label': 'Netral', 'emoji': '😐', 'percent': 0.25, 'color': const Color(0xFFA7E6FF)},
      ],
      'transcripts': [
        {
          'isUser': true,
          'time': '21:45 PM',
          'text': 'Malam ini saya merapikan ulang target besok agar tidak kaget lagi.',
          'emotionTag': 'sadness (55%)',
          'emotionEmoji': '😔',
        },
        {
          'isUser': false,
          'time': '21:46 PM',
          'text': 'Langkah yang sangat bijak. Sekarang matikan gawai dan istirahatlah dengan tenang.',
        },
      ],
    },
  ],
};
