import 'package:flutter/material.dart';
import '../../models/profile_template.dart';
import '../reptiles/reptile.dart';
import '../reptiles/reptile_form_widgets.dart';

class ReptiProfileCard extends StatelessWidget {
  final GlobalKey? cardKey;
  final Reptile reptile;
  final List<ProfileField> fields;
  final ProfileTheme theme;
  final String watermarkText;
  final String fatherName;
  final String motherName;

  const ReptiProfileCard({
    super.key,
    this.cardKey,
    required this.reptile,
    required this.fields,
    required this.theme,
    required this.watermarkText,
    this.fatherName = '미등록',
    this.motherName = '미등록',
  });

  Color get _bgColor => switch (theme) {
        ProfileTheme.dark => const Color(0xFF1A1A2E),
        ProfileTheme.white => Colors.white,
        ProfileTheme.breeder => const Color(0xFF0D2137),
      };

  Color get _textColor => switch (theme) {
        ProfileTheme.dark => Colors.white,
        ProfileTheme.white => const Color(0xFF1A1A2E),
        ProfileTheme.breeder => Colors.white,
      };

  Color get _labelColor => switch (theme) {
        ProfileTheme.dark => Colors.grey,
        ProfileTheme.white => Colors.grey.shade600,
        ProfileTheme.breeder => Colors.grey.shade400,
      };

  Color get _placeholderBg => switch (theme) {
        ProfileTheme.dark => const Color(0xFF252540),
        ProfileTheme.white => const Color(0xFFF0F0F0),
        ProfileTheme.breeder => const Color(0xFF122840),
      };

  String _fieldValue(ProfileField field) => switch (field) {
        ProfileField.name => reptile.name,
        ProfileField.morph => reptile.morph ?? '-',
        ProfileField.sex => switch (reptile.sex) {
            'male' => '♂ 수컷',
            'female' => '♀ 암컷',
            _ => '미확인',
          },
        ProfileField.birthday => reptile.birthday == null
            ? '-'
            : '${reptile.birthday!.year}.'
                '${reptile.birthday!.month.toString().padLeft(2, '0')}.'
                '${reptile.birthday!.day.toString().padLeft(2, '0')}',
        ProfileField.weight => reptile.weightG != null
            ? '${reptile.weightG!.toStringAsFixed(1)}g'
            : '-',
        ProfileField.father => fatherName,
        ProfileField.mother => motherName,
        ProfileField.status => switch (reptile.status) {
            'active' => '활성',
            'holdback' => '홀드백',
            'available' => '분양가능',
            'sold' => '분양완료',
            'deceased' => '무지개다리',
            _ => reptile.status,
          },
        ProfileField.memo => reptile.memo ?? '-',
      };

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: cardKey,
      child: AspectRatio(
        aspectRatio: 9 / 16,
        child: Container(
          decoration: BoxDecoration(
            color: _bgColor,
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 브리더 테마 상단 그라데이션 바
              if (theme == ProfileTheme.breeder)
                Container(
                  height: 5,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF4CAF82), Color(0xFF2E7D52)],
                    ),
                  ),
                ),
              // 이미지 영역 (40%)
              Expanded(flex: 40, child: _buildImage()),
              // 필드 영역 (50%)
              Expanded(flex: 50, child: _buildFields()),
              // 워터마크 영역 (10%)
              Expanded(flex: 10, child: _buildWatermark()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImage() {
    if (reptile.imageUrl != null && reptile.imageUrl!.isNotEmpty) {
      return Image.network(
        reptile.imageUrl!,
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (context, error, stack) => _iconPlaceholder(),
      );
    }
    return _iconPlaceholder();
  }

  Widget _iconPlaceholder() {
    return Container(
      color: _placeholderBg,
      child: Center(
        child: Icon(Icons.pets, size: 56, color: kGreen.withValues(alpha: 0.5)),
      ),
    );
  }

  Widget _buildFields() {
    if (fields.isEmpty) {
      return Center(
        child: Text('표시할 필드 없음',
            style: TextStyle(color: _labelColor, fontSize: 12)),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.6,
        ),
        itemCount: fields.length,
        itemBuilder: (_, i) => _FieldCell(
          label: fields[i].label.toLowerCase(),
          value: _fieldValue(fields[i]),
          labelColor: _labelColor,
          valueColor: _textColor,
        ),
      ),
    );
  }

  Widget _buildWatermark() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(
          watermarkText.isEmpty ? 'ReptiFlow' : watermarkText,
          style: TextStyle(
            color: _textColor.withValues(alpha: 0.35),
            fontSize: 9,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}

class _FieldCell extends StatelessWidget {
  final String label;
  final String value;
  final Color labelColor;
  final Color valueColor;

  const _FieldCell({
    required this.label,
    required this.value,
    required this.labelColor,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
              color: labelColor, fontSize: 9, letterSpacing: 0.4),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            height: 1.2,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
