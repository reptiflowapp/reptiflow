import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/profile_template.dart';
import '../reptiles/reptile.dart';
import '../reptiles/reptile_form_widgets.dart';
import 'repti_profile_card.dart';

class ProfileGeneratorScreen extends StatefulWidget {
  final Reptile reptile;
  const ProfileGeneratorScreen({super.key, required this.reptile});

  @override
  State<ProfileGeneratorScreen> createState() => _ProfileGeneratorScreenState();
}

class _ProfileGeneratorScreenState extends State<ProfileGeneratorScreen> {
  final _screenshotController = ScreenshotController();
  final _cardKey = GlobalKey();
  final _watermarkCtrl = TextEditingController(text: 'ReptiFlow');
  final _templateNameCtrl = TextEditingController();

  ProfileTheme _selectedTheme = ProfileTheme.dark;
  List<ProfileField> _selectedFields = List.of(ProfileField.values);
  List<ProfileTemplate> _templates = [];
  ProfileTemplate? _selectedTemplate;

  String _fatherName = '미등록';
  String _motherName = '미등록';
  bool _isSavingTemplate = false;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
    _loadParentNames();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.reptile.imageUrl != null) {
      precacheImage(NetworkImage(widget.reptile.imageUrl!), context);
    }
  }

  @override
  void dispose() {
    _watermarkCtrl.dispose();
    _templateNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTemplates() async {
    try {
      final rows = await Supabase.instance.client
          .from('profile_templates')
          .select()
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _templates =
              (rows as List).map((r) => ProfileTemplate.fromJson(r)).toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _loadParentNames() async {
    try {
      final row = await Supabase.instance.client
          .from('reptiles')
          .select('father:father_id(name), mother:mother_id(name)')
          .eq('id', widget.reptile.id)
          .single();
      if (!mounted) return;
      setState(() {
        _fatherName =
            (row['father'] as Map<String, dynamic>?)?['name'] as String? ??
                '미등록';
        _motherName =
            (row['mother'] as Map<String, dynamic>?)?['name'] as String? ??
                '미등록';
      });
    } catch (_) {}
  }

  void _applyTemplate(ProfileTemplate t) {
    setState(() {
      _selectedTemplate = t;
      _selectedTheme = t.theme;
      _selectedFields = List.of(t.fieldOrder);
      _watermarkCtrl.text = t.watermarkText;
    });
  }

  void _toggleField(ProfileField field) {
    setState(() {
      if (_selectedFields.contains(field)) {
        _selectedFields.remove(field);
      } else {
        _selectedFields.add(field);
        _selectedFields.sort((a, b) =>
            ProfileField.values.indexOf(a).compareTo(
              ProfileField.values.indexOf(b),
            ));
      }
    });
  }

  Future<void> _saveTemplate() async {
    final templateName = _templateNameCtrl.text.trim();
    if (templateName.isEmpty) {
      _showError('템플릿 이름을 입력해주세요.');
      return;
    }
    setState(() => _isSavingTemplate = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      await Supabase.instance.client.from('profile_templates').insert({
        'user_id': userId,
        'name': templateName,
        'field_order': _selectedFields.map((e) => e.name).toList(),
        'theme': _selectedTheme.name,
        'watermark_text': _watermarkCtrl.text.trim().isEmpty
            ? 'ReptiFlow'
            : _watermarkCtrl.text.trim(),
      });
      _templateNameCtrl.clear();
      await _loadTemplates();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('템플릿이 저장되었습니다.'),
            backgroundColor: kGreen,
          ),
        );
      }
    } on PostgrestException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('템플릿 저장에 실패했습니다.');
    } finally {
      if (mounted) setState(() => _isSavingTemplate = false);
    }
  }

  Future<Uint8List?> _capture() async {
    await Future.delayed(const Duration(milliseconds: 150));
    return _screenshotController.capture(pixelRatio: 3.0);
  }

  Future<void> _saveImage() async {
    setState(() => _isBusy = true);
    try {
      final bytes = await _capture();
      if (bytes == null) {
        _showError('이미지 캡처에 실패했습니다.');
        return;
      }
      final fileName =
          '${widget.reptile.name}_${DateTime.now().millisecondsSinceEpoch}.png';

      if (Platform.isAndroid) {
        final dir = Directory('/storage/emulated/0/Pictures/ReptiFlow');
        await dir.create(recursive: true);
        await File('${dir.path}/$fileName').writeAsBytes(bytes);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('갤러리에 저장되었습니다: $fileName'),
              backgroundColor: kGreen,
            ),
          );
        }
      } else {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(bytes);
        await Share.shareXFiles([XFile(file.path)], text: '갤러리에 저장하세요.');
      }
    } catch (_) {
      _showError('이미지 저장에 실패했습니다.');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _shareImage() async {
    setState(() => _isBusy = true);
    try {
      final bytes = await _capture();
      if (bytes == null) {
        _showError('이미지 캡처에 실패했습니다.');
        return;
      }
      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/${widget.reptile.name}_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: '${widget.reptile.name} 분양 프로필',
        subject: '${widget.reptile.name} 분양 프로필',
      );
    } catch (_) {
      _showError('공유에 실패했습니다.');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: kSurface,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('분양 프로필 생성',
            style: TextStyle(color: Colors.white)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── 설정 단계 ─────────────────────────────────────────────
          const SectionLabel('테마'),
          const SizedBox(height: 12),
          _ThemeChips(
            selected: _selectedTheme,
            onChanged: (t) => setState(() => _selectedTheme = t),
          ),
          const SizedBox(height: 24),

          const SectionLabel('포함 필드'),
          const SizedBox(height: 8),
          _FieldCheckboxList(
            selected: _selectedFields,
            onToggle: _toggleField,
          ),
          const SizedBox(height: 24),

          const SectionLabel('워터마크'),
          const SizedBox(height: 12),
          TextField(
            controller: _watermarkCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: formDecoration('워터마크 텍스트', hint: 'ReptiFlow'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 24),

          const SectionLabel('저장된 템플릿'),
          const SizedBox(height: 12),
          _TemplateDropdown(
            templates: _templates,
            selected: _selectedTemplate,
            onChanged: _applyTemplate,
          ),
          const SizedBox(height: 12),
          _SaveTemplateRow(
            ctrl: _templateNameCtrl,
            isSaving: _isSavingTemplate,
            onSave: _saveTemplate,
          ),
          const SizedBox(height: 32),

          // ── 미리보기 단계 ──────────────────────────────────────────
          const SectionLabel('미리보기'),
          const SizedBox(height: 12),
          Screenshot(
            controller: _screenshotController,
            child: ReptiProfileCard(
              cardKey: _cardKey,
              reptile: widget.reptile,
              fields: _selectedFields,
              theme: _selectedTheme,
              watermarkText: _watermarkCtrl.text.isEmpty
                  ? 'ReptiFlow'
                  : _watermarkCtrl.text,
              fatherName: _fatherName,
              motherName: _motherName,
            ),
          ),
          const SizedBox(height: 24),

          // ── 액션 버튼 ──────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _isBusy ? null : _saveImage,
                    icon: _isBusy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.save_alt, size: 18),
                    label: const Text('이미지로 저장',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kGreen,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: kGreen.withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: _isBusy ? null : _shareImage,
                    icon: const Icon(Icons.share, size: 18),
                    label: const Text('공유하기',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kGreen,
                      side: const BorderSide(color: kGreen),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }
}

// ── 테마 칩 ───────────────────────────────────────────────────────────────────

class _ThemeChips extends StatelessWidget {
  final ProfileTheme selected;
  final ValueChanged<ProfileTheme> onChanged;

  const _ThemeChips({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: ProfileTheme.values.map((t) {
        final isSelected = selected == t;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(t.label),
            selected: isSelected,
            onSelected: (_) => onChanged(t),
            selectedColor: kGreen.withValues(alpha: 0.18),
            backgroundColor: kSurface,
            labelStyle: TextStyle(
              color: isSelected ? kGreen : Colors.grey,
              fontWeight:
                  isSelected ? FontWeight.bold : FontWeight.normal,
            ),
            side: BorderSide(color: isSelected ? kGreen : Colors.transparent),
          ),
        );
      }).toList(),
    );
  }
}

// ── 필드 체크박스 목록 ─────────────────────────────────────────────────────────

class _FieldCheckboxList extends StatelessWidget {
  final List<ProfileField> selected;
  final ValueChanged<ProfileField> onToggle;

  const _FieldCheckboxList(
      {required this.selected, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: ProfileField.values.map((field) {
          final checked = selected.contains(field);
          return InkWell(
            onTap: () => onToggle(field),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: Checkbox(
                      value: checked,
                      onChanged: (_) => onToggle(field),
                      activeColor: kGreen,
                      checkColor: Colors.white,
                      side: const BorderSide(color: Colors.grey),
                      materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    field.label,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── 템플릿 드롭다운 ───────────────────────────────────────────────────────────

class _TemplateDropdown extends StatelessWidget {
  final List<ProfileTemplate> templates;
  final ProfileTemplate? selected;
  final ValueChanged<ProfileTemplate> onChanged;

  const _TemplateDropdown({
    required this.templates,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (templates.isEmpty) {
      return Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text('저장된 템플릿이 없습니다',
            style: TextStyle(color: Colors.grey, fontSize: 14)),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<ProfileTemplate>(
          value: selected,
          hint: const Text('템플릿 선택',
              style: TextStyle(color: Colors.grey)),
          dropdownColor: const Color(0xFF2A2A2A),
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
          items: templates
              .map((t) => DropdownMenuItem(
                    value: t,
                    child: Text(t.name,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 15)),
                  ))
              .toList(),
          onChanged: (t) {
            if (t != null) onChanged(t);
          },
        ),
      ),
    );
  }
}

// ── 템플릿 저장 행 ─────────────────────────────────────────────────────────────

class _SaveTemplateRow extends StatelessWidget {
  final TextEditingController ctrl;
  final bool isSaving;
  final VoidCallback onSave;

  const _SaveTemplateRow({
    required this.ctrl,
    required this.isSaving,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: ctrl,
            style: const TextStyle(color: Colors.white),
            decoration: formDecoration('템플릿 이름'),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          height: 52,
          child: OutlinedButton(
            onPressed: isSaving ? null : onSave,
            style: OutlinedButton.styleFrom(
              foregroundColor: kGreen,
              side: const BorderSide(color: kGreen),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: kGreen),
                  )
                : const Text('저장',
                    style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}
