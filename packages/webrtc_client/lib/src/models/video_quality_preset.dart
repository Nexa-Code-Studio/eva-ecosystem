enum VideoQualityPreset {
  hd720p,
  sd480p,
  audioOnly,
}

extension VideoQualityPresetExtension on VideoQualityPreset {
  String get label {
    switch (this) {
      case VideoQualityPreset.hd720p:
        return '720p HD';
      case VideoQualityPreset.sd480p:
        return '480p Hemat';
      case VideoQualityPreset.audioOnly:
        return 'Audio-Only';
    }
  }

  int get targetWidth {
    switch (this) {
      case VideoQualityPreset.hd720p:
        return 1280;
      case VideoQualityPreset.sd480p:
        return 640;
      case VideoQualityPreset.audioOnly:
        return 0;
    }
  }

  int get targetHeight {
    switch (this) {
      case VideoQualityPreset.hd720p:
        return 720;
      case VideoQualityPreset.sd480p:
        return 480;
      case VideoQualityPreset.audioOnly:
        return 0;
    }
  }

  int get targetFrameRate {
    switch (this) {
      case VideoQualityPreset.hd720p:
      case VideoQualityPreset.sd480p:
        return 30;
      case VideoQualityPreset.audioOnly:
        return 0;
    }
  }

  int? get maxBitrateBps {
    switch (this) {
      case VideoQualityPreset.hd720p:
        return 1500000; // 1.5 Mbps
      case VideoQualityPreset.sd480p:
        return 800000; // 800 kbps
      case VideoQualityPreset.audioOnly:
        return 64000; // 64 kbps (audio)
    }
  }
}
