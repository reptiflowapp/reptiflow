import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/r2_uploader.dart';
import 'reptile_form_widgets.dart';

class AddReptileScreen extends StatefulWidget {
  const AddReptileScreen({super.key});

  @override
  State<AddReptileScreen> createState() => _AddReptileScreenState();
}

class _AddReptileScreenState extends State<AddReptileScreen> {
  final _nameCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _memoCtrl = TextEditingController();
  int _intervalDays = 7;

  String _sex = 'unknown';
  String _status = 'active';
  DateTime? _birthday;
  String? _species;
  String? _morph;
  Uint8List? _imageBytes;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _weightCtrl.dispose();
    _memoCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final file = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() => _imageBytes = bytes);
  }

  Future<String> _uploadImage(Uint8List bytes, String userId) async {
    final key =
        '$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
    return R2Uploader.upload(bytes, key);
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      _showError('이름을 입력해주세요.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final weightText = _weightCtrl.text.trim();

      // 1. insert → ID 반환
      final result = await Supabase.instance.client
          .from('reptiles')
          .insert({
            'user_id': userId,
            'name': _nameCtrl.text.trim(),
            'species': _species,
            'morph': _morph,
            'sex': _sex,
            'status': _status,
            'birthday': _birthday == null
                ? null
                : '${_birthday!.year}-${_birthday!.month.toString().padLeft(2, '0')}-${_birthday!.day.toString().padLeft(2, '0')}',
            'weight_g':
                weightText.isEmpty ? null : double.tryParse(weightText),
            'memo':
                _memoCtrl.text.trim().isEmpty ? null : _memoCtrl.text.trim(),
            'feeding_interval_days': _intervalDays,
          })
          .select('id')
          .single();

      final reptileId = result['id'] as String;

      // 2. 이미지 업로드 후 image_url 갱신
      if (_imageBytes != null) {
        final imageUrl = await _uploadImage(_imageBytes!, userId);
        await Supabase.instance.client
            .from('reptiles')
            .update({'image_url': imageUrl})
            .eq('id', reptileId);
      }

      if (mounted) Navigator.pop(context);
    } on PostgrestException catch (e) {
      _showError(e.message);
    } on StorageException catch (e) {
      _showError('이미지 업로드 실패: ${e.message}');
    } catch (_) {
      _showError('저장 중 오류가 발생했습니다.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  Future<void> _pickBirthday() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthday ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: kGreen,
            surface: Color(0xFF2A2A2A),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _birthday = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: kSurface,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('개체 추가', style: TextStyle(color: Colors.white)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _isLoading ? null : _save,
              child: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: kGreen),
                    )
                  : const Text('저장',
                      style: TextStyle(
                          color: kGreen, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── 사진 ───────────────────────────────────────────────────
          ReptileImagePicker(
            imageBytes: _imageBytes,
            onTap: _pickImage,
          ),
          const SizedBox(height: 28),

          // ── 기본 정보 ──────────────────────────────────────────────
          const SectionLabel('기본 정보'),
          const SizedBox(height: 12),
          TextField(
            controller: _nameCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: formDecoration('이름 *'),
          ),
          const SizedBox(height: 28),

          // ── 종 / 모프 ──────────────────────────────────────────────
          const SectionLabel('종 / 모프'),
          const SizedBox(height: 12),
          SpeciesMorphPicker(
            onChanged: (s, m) {
              _species = s;
              _morph = m;
            },
          ),
          const SizedBox(height: 28),

          // ── 성별 ──────────────────────────────────────────────────
          const SectionLabel('성별'),
          const SizedBox(height: 12),
          SexSelector(
            value: _sex,
            onChanged: (v) => setState(() => _sex = v),
          ),
          const SizedBox(height: 28),

          // ── 상태 ──────────────────────────────────────────────────
          const SectionLabel('상태'),
          const SizedBox(height: 12),
          StatusDropdown(
            value: _status,
            onChanged: (v) => setState(() => _status = v),
          ),
          const SizedBox(height: 28),

          // ── 상세 정보 ──────────────────────────────────────────────
          const SectionLabel('상세 정보'),
          const SizedBox(height: 12),
          BirthdayPicker(
            value: _birthday,
            onTap: _pickBirthday,
            onClear: () => setState(() => _birthday = null),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _weightCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: Colors.white),
            decoration: formDecoration('몸무게 (g)', hint: '예: 45.5'),
          ),
          const SizedBox(height: 12),
          FeedingIntervalPicker(
            value: _intervalDays,
            onChanged: (v) => setState(() => _intervalDays = v),
          ),
          const SizedBox(height: 28),

          // ── 메모 ──────────────────────────────────────────────────
          const SectionLabel('메모'),
          const SizedBox(height: 12),
          TextField(
            controller: _memoCtrl,
            style: const TextStyle(color: Colors.white),
            maxLines: 4,
            decoration: formDecoration('메모'),
          ),
          const SizedBox(height: 32),

          // ── 저장 버튼 ──────────────────────────────────────────────
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: kGreen,
                foregroundColor: Colors.white,
                disabledBackgroundColor: kGreen.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Text('저장',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }
}
