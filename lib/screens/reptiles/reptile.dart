class Reptile {
  final String id;
  final String name;
  final String? species;
  final String? morph;
  final String sex;     // 'male' | 'female' | 'unknown'
  final String status;  // 'active' | 'holdback' | 'available' | 'sold' | 'deceased'
  final DateTime? birthday;
  final double? weightG;
  final String? memo;
  final String? imageUrl;
  final DateTime createdAt;
  final int feedingIntervalDays;

  const Reptile({
    required this.id,
    required this.name,
    this.species,
    this.morph,
    required this.sex,
    required this.status,
    this.birthday,
    this.weightG,
    this.memo,
    this.imageUrl,
    required this.createdAt,
    this.feedingIntervalDays = 7,
  });

  factory Reptile.fromJson(Map<String, dynamic> j) => Reptile(
        id: j['id'] as String,
        name: j['name'] as String,
        species: j['species'] as String?,
        morph: j['morph'] as String?,
        sex: j['sex'] as String? ?? 'unknown',
        status: j['status'] as String? ?? 'active',
        birthday: j['birthday'] != null
            ? DateTime.parse(j['birthday'] as String)
            : null,
        weightG:
            j['weight_g'] != null ? (j['weight_g'] as num).toDouble() : null,
        memo: j['memo'] as String?,
        imageUrl: j['image_url'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
        feedingIntervalDays:
            j['feeding_interval_days'] as int? ?? 7,
      );
}
