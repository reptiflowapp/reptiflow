enum ProfileField {
  name,
  morph,
  sex,
  birthday,
  weight,
  father,
  mother,
  status,
  memo;

  String get label => switch (this) {
        ProfileField.name => '이름',
        ProfileField.morph => '모프',
        ProfileField.sex => '성별',
        ProfileField.birthday => '해칭일',
        ProfileField.weight => '몸무게',
        ProfileField.father => '아버지 개체',
        ProfileField.mother => '어머니 개체',
        ProfileField.status => '상태',
        ProfileField.memo => '특이사항',
      };

  static ProfileField fromString(String s) => ProfileField.values.firstWhere(
        (e) => e.name == s,
        orElse: () => ProfileField.name,
      );
}

enum ProfileTheme {
  dark,
  white,
  breeder;

  String get label => switch (this) {
        ProfileTheme.dark => '다크',
        ProfileTheme.white => '화이트',
        ProfileTheme.breeder => '브리더',
      };

  static ProfileTheme fromString(String s) => ProfileTheme.values.firstWhere(
        (e) => e.name == s,
        orElse: () => ProfileTheme.dark,
      );
}

class ProfileTemplate {
  final String id;
  final String userId;
  final String name;
  final List<ProfileField> fieldOrder;
  final ProfileTheme theme;
  final String watermarkText;
  final DateTime createdAt;

  const ProfileTemplate({
    required this.id,
    required this.userId,
    required this.name,
    required this.fieldOrder,
    required this.theme,
    required this.watermarkText,
    required this.createdAt,
  });

  factory ProfileTemplate.fromJson(Map<String, dynamic> j) => ProfileTemplate(
        id: j['id'] as String,
        userId: j['user_id'] as String,
        name: j['name'] as String,
        fieldOrder: (j['field_order'] as List<dynamic>)
            .map((e) => ProfileField.fromString(e as String))
            .toList(),
        theme: ProfileTheme.fromString(j['theme'] as String? ?? 'dark'),
        watermarkText: j['watermark_text'] as String? ?? 'ReptiFlow',
        createdAt: DateTime.parse(j['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'name': name,
        'field_order': fieldOrder.map((e) => e.name).toList(),
        'theme': theme.name,
        'watermark_text': watermarkText,
      };
}
