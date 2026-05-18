import 'dart:typed_data';
import 'package:flutter/material.dart';

// ── Species / Morph data ──────────────────────────────────────────────────────

const List<String> kSpeciesList = [
  '크레스티드게코',
  '레오파드게코',
  '볼파이톤',
  '비어디드래곤',
  '콘스네이크',
  '블루텅스킨크',
  '기타',
];

const Map<String, List<String>> kMorphsBySpecies = {
  '크레스티드게코': [
    '릴리화이트', '하렐퀸', '달마시안', '슈달(슈퍼달마시안)', '슈달(필리스팟)',
    '핀스트라이프', '버크스킨', '익스트림 하렐퀸', '노멀', '쵸쵸', '파이드', '기타',
  ],
  '레오파드게코': ['알비노', '블리자드', '멜라니스틱', '탱제린', '마크 스노우', '기타'],
  '볼파이톤': ['파이볼', '클라운', '스파이더', '팬더', '기타'],
  '비어디드래곤': ['레더백', '실크백', '던너', '기타'],
  '콘스네이크': ['기타'],
  '블루텅스킨크': ['기타'],
  '기타': ['기타'],
};

// ── Shared style helpers ──────────────────────────────────────────────────────

const Color kGreen = Color(0xFF4CAF82);
const Color kSurface = Color(0xFF1E1E1E);

InputDecoration formDecoration(String label, {String? hint}) => InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: Colors.grey),
      hintStyle: const TextStyle(color: Color(0xFF555555)),
      filled: true,
      fillColor: kSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kGreen),
      ),
    );

// ── SectionLabel ──────────────────────────────────────────────────────────────

class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
            color: Colors.grey, fontSize: 12, letterSpacing: 0.5),
      );
}

// ── SexSelector ───────────────────────────────────────────────────────────────

class SexSelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const SexSelector({super.key, required this.value, required this.onChanged});

  static const _options = [
    ('male', '♂ 수컷', Color(0xFF42A5F5)),
    ('female', '♀ 암컷', Color(0xFFF48FB1)),
    ('unknown', '미확인', Color(0xFF9E9E9E)),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _options.map((opt) {
        final (val, label, color) = opt;
        final selected = value == val;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onChanged(val),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  color: selected
                      ? color.withValues(alpha: 0.15)
                      : kSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected ? color : Colors.transparent,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected ? color : Colors.grey,
                    fontWeight:
                        selected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── StatusDropdown ────────────────────────────────────────────────────────────

class StatusDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const StatusDropdown(
      {super.key, required this.value, required this.onChanged});

  static const _options = [
    ('active', '활성', Color(0xFF4CAF82)),
    ('holdback', '홀드백', Color(0xFFFF9800)),
    ('available', '분양가능', Color(0xFF42A5F5)),
    ('sold', '분양완료', Color(0xFF9E9E9E)),
    ('deceased', '무지개다리', Color(0xFFEF5350)),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          dropdownColor: const Color(0xFF2A2A2A),
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
          items: _options.map((opt) {
            final (val, label, color) = opt;
            return DropdownMenuItem(
              value: val,
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration:
                        BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 10),
                  Text(label,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 15)),
                ],
              ),
            );
          }).toList(),
          onChanged: (v) => onChanged(v!),
        ),
      ),
    );
  }
}

// ── BirthdayPicker ────────────────────────────────────────────────────────────

class BirthdayPicker extends StatelessWidget {
  final DateTime? value;
  final VoidCallback onTap;
  final VoidCallback onClear;
  const BirthdayPicker(
      {super.key,
      required this.value,
      required this.onTap,
      required this.onClear});

  String _fmt(DateTime d) =>
      '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined,
                color: Colors.grey, size: 18),
            const SizedBox(width: 12),
            Text(
              value != null ? _fmt(value!) : '생일 선택',
              style: TextStyle(
                color: value != null ? Colors.white : Colors.grey,
                fontSize: 16,
              ),
            ),
            const Spacer(),
            if (value != null)
              GestureDetector(
                onTap: onClear,
                child:
                    const Icon(Icons.close, color: Colors.grey, size: 18),
              ),
          ],
        ),
      ),
    );
  }
}

// ── SpeciesMorphPicker ────────────────────────────────────────────────────────
//
// 종 선택 → 해당 종의 모프 목록 표시.
// '기타' 선택 시 자유 입력 TextField 노출.
// 종이 '기타'이면 모프도 바로 자유 입력.

class SpeciesMorphPicker extends StatefulWidget {
  final String? initialSpecies;
  final String? initialMorph;

  // 종·모프 중 하나라도 바뀔 때마다 호출. null = 미입력.
  final void Function(String? species, String? morph) onChanged;

  const SpeciesMorphPicker({
    super.key,
    this.initialSpecies,
    this.initialMorph,
    required this.onChanged,
  });

  @override
  State<SpeciesMorphPicker> createState() => _SpeciesMorphPickerState();
}

class _SpeciesMorphPickerState extends State<SpeciesMorphPicker> {
  // '_speciesKey': 드롭다운 선택값 (kSpeciesList 중 하나, 또는 null)
  String? _speciesKey;
  // '_morphKey': 드롭다운 선택값 (kMorphsBySpecies 리스트 중 하나, 또는 null)
  String? _morphKey;

  late final TextEditingController _customSpeciesCtrl;
  late final TextEditingController _customMorphCtrl;

  @override
  void initState() {
    super.initState();

    final initSpecies = widget.initialSpecies ?? '';
    if (initSpecies.isEmpty) {
      _speciesKey = null;
      _customSpeciesCtrl = TextEditingController();
    } else if (kSpeciesList.contains(initSpecies)) {
      _speciesKey = initSpecies;
      _customSpeciesCtrl = TextEditingController();
    } else {
      _speciesKey = '기타';
      _customSpeciesCtrl = TextEditingController(text: initSpecies);
    }

    final initMorph = widget.initialMorph ?? '';
    final morphList = _morphListFor(_speciesKey);
    if (initMorph.isEmpty) {
      _morphKey = null;
      _customMorphCtrl = TextEditingController();
    } else if (_speciesKey == '기타') {
      // 종이 기타이면 모프도 자유입력
      _morphKey = null;
      _customMorphCtrl = TextEditingController(text: initMorph);
    } else if (morphList.contains(initMorph)) {
      _morphKey = initMorph;
      _customMorphCtrl = TextEditingController();
    } else {
      _morphKey = '기타';
      _customMorphCtrl = TextEditingController(text: initMorph);
    }
  }

  @override
  void dispose() {
    _customSpeciesCtrl.dispose();
    _customMorphCtrl.dispose();
    super.dispose();
  }

  List<String> _morphListFor(String? speciesKey) {
    if (speciesKey == null || speciesKey == '기타') return [];
    return kMorphsBySpecies[speciesKey] ?? ['기타'];
  }

  String? get _resolvedSpecies {
    if (_speciesKey == null) return null;
    if (_speciesKey == '기타') {
      final t = _customSpeciesCtrl.text.trim();
      return t.isEmpty ? null : t;
    }
    return _speciesKey;
  }

  String? get _resolvedMorph {
    if (_speciesKey == null) return null;
    if (_speciesKey == '기타') {
      // 자유입력 모프
      final t = _customMorphCtrl.text.trim();
      return t.isEmpty ? null : t;
    }
    if (_morphKey == null) return null;
    if (_morphKey == '기타') {
      final t = _customMorphCtrl.text.trim();
      return t.isEmpty ? null : t;
    }
    return _morphKey;
  }

  void _notify() => widget.onChanged(_resolvedSpecies, _resolvedMorph);

  void _onSpeciesChanged(String? v) {
    setState(() {
      _speciesKey = v;
      _customSpeciesCtrl.clear();
      _morphKey = null;
      _customMorphCtrl.clear();
    });
    _notify();
  }

  @override
  Widget build(BuildContext context) {
    final morphList = _morphListFor(_speciesKey);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 종 드롭다운 ──────────────────────────────────────
        _SelectDropdown(
          hint: '종 선택',
          value: _speciesKey,
          items: kSpeciesList,
          onChanged: _onSpeciesChanged,
        ),

        // 종 '기타' 직접 입력
        if (_speciesKey == '기타') ...[
          const SizedBox(height: 10),
          TextField(
            controller: _customSpeciesCtrl,
            style: const TextStyle(color: Colors.white),
            onChanged: (_) => _notify(),
            decoration: formDecoration('종 직접 입력', hint: '종 이름을 입력하세요'),
          ),
        ],

        // ── 모프 ─────────────────────────────────────────────
        if (_speciesKey != null) ...[
          const SizedBox(height: 12),

          if (_speciesKey == '기타')
            // 종이 기타이면 모프도 자유입력
            TextField(
              controller: _customMorphCtrl,
              style: const TextStyle(color: Colors.white),
              onChanged: (_) => _notify(),
              decoration:
                  formDecoration('모프', hint: '모프를 입력하세요 (선택)'),
            )
          else ...[
            _SelectDropdown(
              hint: '모프 선택',
              value: morphList.contains(_morphKey) ? _morphKey : null,
              items: morphList,
              onChanged: (v) {
                setState(() {
                  _morphKey = v;
                  _customMorphCtrl.clear();
                });
                _notify();
              },
            ),
            // 모프 '기타' 직접 입력
            if (_morphKey == '기타') ...[
              const SizedBox(height: 10),
              TextField(
                controller: _customMorphCtrl,
                style: const TextStyle(color: Colors.white),
                onChanged: (_) => _notify(),
                decoration:
                    formDecoration('모프 직접 입력', hint: '모프 이름을 입력하세요'),
              ),
            ],
          ],
        ],
      ],
    );
  }
}

// ── _SelectDropdown (내부용) ──────────────────────────────────────────────────

class _SelectDropdown extends StatelessWidget {
  final String? value;
  final List<String> items;
  final String hint;
  final ValueChanged<String?> onChanged;

  const _SelectDropdown({
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(hint, style: const TextStyle(color: Colors.grey)),
          dropdownColor: const Color(0xFF2A2A2A),
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
          items: items
              .map((item) => DropdownMenuItem(
                    value: item,
                    child: Text(item,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 15)),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// ── ReptileImagePicker ────────────────────────────────────────────────────────
//
// 사진 없을 때: 카메라 아이콘 + "사진 추가" 텍스트
// 사진 있을 때: 미리보기 + "사진 변경" 오버레이

class ReptileImagePicker extends StatelessWidget {
  final Uint8List? imageBytes;  // 갤러리에서 새로 고른 이미지
  final String? existingUrl;   // 기존 저장된 이미지 URL (수정 화면)
  final VoidCallback onTap;

  const ReptileImagePicker({
    super.key,
    this.imageBytes,
    this.existingUrl,
    required this.onTap,
  });

  bool get _hasImage => imageBytes != null || existingUrl != null;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _hasImage ? Colors.transparent : const Color(0xFF333333),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 이미지 or 플레이스홀더
            if (imageBytes != null)
              Image.memory(imageBytes!, fit: BoxFit.cover)
            else if (existingUrl != null)
              Image.network(
                existingUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _Placeholder(),
              )
            else
              _Placeholder(),

            // 이미지가 있을 때 "사진 변경" 오버레이
            if (_hasImage)
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit, color: Colors.white, size: 12),
                      SizedBox(width: 4),
                      Text('사진 변경',
                          style:
                              TextStyle(color: Colors.white, fontSize: 12)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_a_photo_outlined,
              size: 40, color: Colors.grey.shade600),
          const SizedBox(height: 8),
          Text('사진 추가',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
        ],
      );
}

// ── FeedingIntervalPicker ─────────────────────────────────────────────────────

class FeedingIntervalPicker extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const FeedingIntervalPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          '급여 주기',
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
        const Spacer(),
        IconButton(
          onPressed: value > 1 ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove_circle_outline),
          color: kGreen,
          disabledColor: const Color(0xFF333333),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        SizedBox(
          width: 48,
          child: Text(
            '$value일',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        IconButton(
          onPressed: value < 15 ? () => onChanged(value + 1) : null,
          icon: const Icon(Icons.add_circle_outline),
          color: kGreen,
          disabledColor: const Color(0xFF333333),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }
}

