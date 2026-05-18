import '../models/feeding.dart';

enum VoiceCommandType { feeding, weight, memo, unknown }

class VoiceCommand {
  final VoiceCommandType type;
  final String? reptileName;
  final FeedingStatus? status;
  final double? weightValue;
  final String? memo;
  final String rawText;

  const VoiceCommand({
    required this.type,
    this.reptileName,
    this.status,
    this.weightValue,
    this.memo,
    required this.rawText,
  });
}

class VoiceParserService {
  VoiceParserService._();

  static VoiceCommand parse(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return VoiceCommand(type: VoiceCommandType.unknown, rawText: text);
    }

    final lower = trimmed.toLowerCase();
    // 첫 단어를 개체 이름으로 사용
    final words = trimmed.split(RegExp(r'\s+'));
    final reptileName = words.isNotEmpty ? words.first : null;

    // ── 체중 키워드 (숫자+g / 그램 / 몸무게) ─────────────────────────────
    final hasWeightKeyword = lower.contains('그램') ||
        lower.contains('몸무게') ||
        RegExp(r'\d+\s*g').hasMatch(lower);
    if (hasWeightKeyword) {
      final match = RegExp(r'(\d+\.?\d*)').firstMatch(trimmed);
      final weightValue =
          match != null ? double.tryParse(match.group(1)!) : null;
      return VoiceCommand(
        type: VoiceCommandType.weight,
        reptileName: reptileName,
        weightValue: weightValue,
        rawText: text,
      );
    }

    // ── 거부 키워드 ───────────────────────────────────────────────────────
    if (lower.contains('거부') ||
        lower.contains('안먹') ||
        lower.contains('먹지않')) {
      return VoiceCommand(
        type: VoiceCommandType.feeding,
        reptileName: reptileName,
        status: FeedingStatus.refused,
        rawText: text,
      );
    }

    // ── 부분섭식 키워드 ───────────────────────────────────────────────────
    if (lower.contains('부분') ||
        lower.contains('조금') ||
        lower.contains('반만')) {
      return VoiceCommand(
        type: VoiceCommandType.feeding,
        reptileName: reptileName,
        status: FeedingStatus.partial,
        rawText: text,
      );
    }

    // ── 급여완료 키워드 ───────────────────────────────────────────────────
    const feedingKeywords = [
      '급여', '먹었', '먹임', '사료', '레파시', '완료',
    ];
    if (feedingKeywords.any((k) => lower.contains(k))) {
      return VoiceCommand(
        type: VoiceCommandType.feeding,
        reptileName: reptileName,
        status: FeedingStatus.fed,
        rawText: text,
      );
    }

    // ── 메모 키워드 ───────────────────────────────────────────────────────
    if (lower.contains('메모') || lower.contains('노트') || lower.contains('기록')) {
      final memoText = words.length > 1 ? words.skip(1).join(' ') : null;
      return VoiceCommand(
        type: VoiceCommandType.memo,
        reptileName: reptileName,
        memo: memoText,
        rawText: text,
      );
    }

    return VoiceCommand(
      type: VoiceCommandType.unknown,
      reptileName: reptileName,
      rawText: text,
    );
  }
}
