import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/r2_uploader.dart';
import '../feeding/feeding_log_screen.dart';
import '../feeding/feeding_history_widget.dart';
import '../breeding/breeding_log_screen.dart';
import '../breeding/egg_clutch_screen.dart';
import '../profile/profile_generator_screen.dart';
import 'reptile_form_widgets.dart';
import 'reptile.dart';

class EditReptileScreen extends StatefulWidget {
  final Reptile reptile;
  const EditReptileScreen({super.key, required this.reptile});

  @override
  State<EditReptileScreen> createState() => _EditReptileScreenState();
}

class _EditReptileScreenState extends State<EditReptileScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _weightCtrl;
  late final TextEditingController _memoCtrl;
  late int _intervalDays;

  late String _sex;
  late String _status;
  late DateTime? _birthday;
  late String? _species;
  late String? _morph;
  Uint8List? _imageBytes; // 새로 선택한 이미지 (null이면 기존 URL 유지)
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final r = widget.reptile;
    _nameCtrl = TextEditingController(text: r.name);
    _weightCtrl = TextEditingController(
        text: r.weightG != null ? r.weightG!.toStringAsFixed(1) : '');
    _memoCtrl = TextEditingController(text: r.memo ?? '');
    _intervalDays = r.feedingIntervalDays;
    _sex = r.sex;
    _status = r.status;
    _birthday = r.birthday;
    _species = r.species;
    _morph = r.morph;
  }

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
    final key = '$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
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

      // 새 이미지를 골랐으면 업로드, 아니면 기존 URL 유지
      String? imageUrl = widget.reptile.imageUrl;
      if (_imageBytes != null) {
        imageUrl = await _uploadImage(_imageBytes!, userId);
      }

      await Supabase.instance.client
          .from('reptiles')
          .update({
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
            'image_url': imageUrl,
            'feeding_interval_days': _intervalDays,
          })
          .eq('id', widget.reptile.id);

      if (mounted) Navigator.pop(context, true);
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

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text('개체 삭제', style: TextStyle(color: Colors.white)),
        content: Text(
          '\'${widget.reptile.name}\'을(를) 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제',
                style: TextStyle(
                    color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client
          .from('reptiles')
          .delete()
          .eq('id', widget.reptile.id);

      if (mounted) Navigator.pop(context, true);
    } on PostgrestException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('삭제 중 오류가 발생했습니다.');
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
        title: const Text('개체 수정', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            tooltip: '삭제',
            onPressed: _isLoading ? null : _delete,
          ),
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
            existingUrl: widget.reptile.imageUrl,
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
            initialSpecies: widget.reptile.species,
            initialMorph: widget.reptile.morph,
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
          const SizedBox(height: 16),

          // ── 급여 기록 버튼 ──────────────────────────────────────────
          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FeedingLogScreen(
                    reptileId: widget.reptile.id,
                    reptileName: widget.reptile.name,
                    feedingIntervalDays: widget.reptile.feedingIntervalDays,
                  ),
                ),
              ),
              icon: const Icon(Icons.restaurant_outlined, size: 18),
              label: const Text('급여 기록',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: kGreen,
                side: const BorderSide(color: kGreen),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 28),

          // ── 브리딩 버튼 ────────────────────────────────────────────
          if (widget.reptile.sex == 'male' ||
              widget.reptile.sex == 'female') ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 52,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BreedingLogScreen(
                      reptileId: widget.reptile.id,
                      reptileName: widget.reptile.name,
                      sex: widget.reptile.sex,
                    ),
                  ),
                ),
                icon: const Icon(Icons.favorite_border, size: 18),
                label: const Text('메이팅 기록',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kGreen,
                  side: const BorderSide(color: kGreen),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
          if (widget.reptile.sex == 'female') ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 52,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EggClutchScreen(
                      femaleId: widget.reptile.id,
                      femaleName: widget.reptile.name,
                    ),
                  ),
                ),
                icon: const Icon(Icons.egg_outlined, size: 18),
                label: const Text('산란 기록',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kGreen,
                  side: const BorderSide(color: kGreen),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),

          // ── 분양 프로필 생성 ────────────────────────────────────────
          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      ProfileGeneratorScreen(reptile: widget.reptile),
                ),
              ),
              icon: const Icon(Icons.card_membership, size: 18),
              label: const Text('분양 프로필 생성',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: kGreen,
                side: const BorderSide(color: kGreen),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 28),

          // ── 급여 히스토리 ───────────────────────────────────────────
          const Text(
            '급여 기록',
            style: TextStyle(
                color: Colors.grey, fontSize: 12, letterSpacing: 0.5),
          ),
          const SizedBox(height: 10),
          FeedingHistoryWidget(reptileId: widget.reptile.id),
          const SizedBox(height: 48),
        ],
      ),
    );
  }
}
