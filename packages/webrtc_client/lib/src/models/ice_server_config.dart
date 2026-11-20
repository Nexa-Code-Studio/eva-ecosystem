class IceServerConfig {
  final List<String> urls;
  final String? username;
  final String? credential;

  const IceServerConfig({
    required this.urls,
    this.username,
    this.credential,
  });

  factory IceServerConfig.fromJson(Map<String, dynamic> json) {
    final rawUrls = json['urls'];
    List<String> parsedUrls = [];
    if (rawUrls is List) {
      parsedUrls = rawUrls.map((e) => e.toString()).toList();
    } else if (rawUrls is String) {
      parsedUrls = [rawUrls];
    }
    return IceServerConfig(
      urls: parsedUrls,
      username: json['username']?.toString(),
      credential: json['credential']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{'urls': urls};
    if (username != null && username!.isNotEmpty) {
      map['username'] = username;
    }
    if (credential != null && credential!.isNotEmpty) {
      map['credential'] = credential;
    }
    return map;
  }
}
