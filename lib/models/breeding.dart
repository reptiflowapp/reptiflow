class BreedingLog {
  final String id;
  final String? maleId;
  final String? femaleId;
  final DateTime pairedAt;
  final DateTime? separatedAt;
  final bool? success;
  final String? memo;
  final DateTime createdAt;
  final String? maleName;
  final String? femaleName;

  const BreedingLog({
    required this.id,
    this.maleId,
    this.femaleId,
    required this.pairedAt,
    this.separatedAt,
    this.success,
    this.memo,
    required this.createdAt,
    this.maleName,
    this.femaleName,
  });

  factory BreedingLog.fromJson(Map<String, dynamic> j) => BreedingLog(
        id: j['id'] as String,
        maleId: j['male_id'] as String?,
        femaleId: j['female_id'] as String?,
        pairedAt: DateTime.parse(j['paired_at'] as String).toLocal(),
        separatedAt: j['separated_at'] != null
            ? DateTime.parse(j['separated_at'] as String).toLocal()
            : null,
        success: j['success'] as bool?,
        memo: j['memo'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String).toLocal(),
        maleName: (j['male'] as Map<String, dynamic>?)?['name'] as String?,
        femaleName: (j['female'] as Map<String, dynamic>?)?['name'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'male_id': maleId,
        'female_id': femaleId,
        'paired_at': pairedAt.toUtc().toIso8601String(),
        if (separatedAt != null)
          'separated_at': separatedAt!.toUtc().toIso8601String(),
        if (success != null) 'success': success,
        if (memo != null && memo!.isNotEmpty) 'memo': memo,
      };
}

class EggClutch {
  final String id;
  final String femaleId;
  final String? breedingLogId;
  final DateTime laidAt;
  final int totalEggs;
  final int fertile;
  final DateTime? expectedHatchDate;
  final String? memo;
  final DateTime createdAt;

  const EggClutch({
    required this.id,
    required this.femaleId,
    this.breedingLogId,
    required this.laidAt,
    required this.totalEggs,
    required this.fertile,
    this.expectedHatchDate,
    this.memo,
    required this.createdAt,
  });

  int get infertile => totalEggs - fertile;

  int get dDay {
    if (expectedHatchDate == null) return 0;
    final today = DateTime.now();
    final d = DateTime(today.year, today.month, today.day);
    final e = DateTime(
        expectedHatchDate!.year, expectedHatchDate!.month, expectedHatchDate!.day);
    return e.difference(d).inDays;
  }

  factory EggClutch.fromJson(Map<String, dynamic> j) => EggClutch(
        id: j['id'] as String,
        femaleId: j['female_id'] as String,
        breedingLogId: j['breeding_log_id'] as String?,
        laidAt: DateTime.parse(j['laid_at'] as String),
        totalEggs: j['total_eggs'] as int,
        fertile: j['fertile'] as int,
        expectedHatchDate: j['expected_hatch_date'] != null
            ? DateTime.parse(j['expected_hatch_date'] as String)
            : null,
        memo: j['memo'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String).toLocal(),
      );

  Map<String, dynamic> toJson() => {
        'female_id': femaleId,
        if (breedingLogId != null) 'breeding_log_id': breedingLogId,
        'laid_at':
            '${laidAt.year}-${laidAt.month.toString().padLeft(2, '0')}-${laidAt.day.toString().padLeft(2, '0')}',
        'total_eggs': totalEggs,
        'fertile': fertile,
        'infertile': infertile,
        if (expectedHatchDate != null)
          'expected_hatch_date':
              '${expectedHatchDate!.year}-${expectedHatchDate!.month.toString().padLeft(2, '0')}-${expectedHatchDate!.day.toString().padLeft(2, '0')}',
        if (memo != null && memo!.isNotEmpty) 'memo': memo,
      };
}

class HatchRecord {
  final String id;
  final String clutchId;
  final DateTime hatchedAt;
  final int hatchedCount;
  final String? memo;
  final DateTime createdAt;

  const HatchRecord({
    required this.id,
    required this.clutchId,
    required this.hatchedAt,
    required this.hatchedCount,
    this.memo,
    required this.createdAt,
  });

  factory HatchRecord.fromJson(Map<String, dynamic> j) => HatchRecord(
        id: j['id'] as String,
        clutchId: j['clutch_id'] as String,
        hatchedAt: DateTime.parse(j['hatched_at'] as String),
        hatchedCount: j['hatched_count'] as int,
        memo: j['memo'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String).toLocal(),
      );

  Map<String, dynamic> toJson() => {
        'clutch_id': clutchId,
        'hatched_at':
            '${hatchedAt.year}-${hatchedAt.month.toString().padLeft(2, '0')}-${hatchedAt.day.toString().padLeft(2, '0')}',
        'hatched_count': hatchedCount,
        if (memo != null && memo!.isNotEmpty) 'memo': memo,
      };
}
