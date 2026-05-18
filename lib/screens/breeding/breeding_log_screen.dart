import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/breeding.dart';

const _kGreen = Color(0xFF4CAF82);
const _kSurface = Color(0xFF1E1E1E);
const _kCard = Color(0xFF2A2A2A);

class BreedingLogScreen extends StatefulWidget {
  final String reptileId;
  final String reptileName;
  final String sex; // 'male' or 'female'

  const BreedingLogScreen({
    super.key,
    required this.reptileId,
    required this.reptileName,
    required this.sex,
  });

  @override
  State<BreedingLogScreen> createState() => _BreedingLogScreenState();
}

class _BreedingLogScreenState extends State<BreedingLogScreen> {
  List<BreedingLog> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      // Join to get partner names via male/female FK aliases
      final data = await Supabase.instance.client
          .from('breeding_logs')
          .select('*, male:reptiles!male_id(name), female:reptiles!female_id(name)')
          .or('male_id.eq.${widget.reptileId},female_id.eq.${widget.reptileId}')
          .order('paired_at', ascending: false);

      if (mounted) {
        setState(() {
          _logs = (data as List)
              .map((e) => BreedingLog.fromJson(e as Map<String, dynamic>))
              .toList();
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showAddSheet() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _kCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _BreedingLogSheet(
        reptileId: widget.reptileId,
        sex: widget.sex,
      ),
    );
    if (result == true) _load();
  }

  String _fmtDate(DateTime dt) =>
      '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';

  Widget _successBadge(bool? success) {
    if (success == null) {
      return _badge('미확인', const Color(0xFF888888));
    }
    return success
        ? _badge('성공', _kGreen)
        : _badge('실패', Colors.redAccent);
  }

  Widget _badge(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(
          label,
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: _kSurface,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '${widget.reptileName} · 메이팅 기록',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: _kGreen),
            onPressed: _showAddSheet,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _kGreen))
          : _logs.isEmpty
              ? const Center(
                  child: Text(
                    '메이팅 기록이 없어요',
                    style: TextStyle(color: Colors.grey, fontSize: 15),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _logs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final log = _logs[i];
                    final partnerName = widget.sex == 'male'
                        ? (log.femaleName ?? '(삭제된 개체)')
                        : (log.maleName ?? '(삭제된 개체)');
                    final partnerLabel =
                        widget.sex == 'male' ? '암컷' : '수컷';

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _kCard,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                _fmtDate(log.pairedAt),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14),
                              ),
                              const Spacer(),
                              _successBadge(log.success),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.pets,
                                  size: 14, color: Colors.grey.shade600),
                              const SizedBox(width: 4),
                              Text(
                                '$partnerLabel: $partnerName',
                                style: const TextStyle(
                                    color: Color(0xFFBBBBBB), fontSize: 13),
                              ),
                            ],
                          ),
                          if (log.separatedAt != null) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.call_split,
                                    size: 14, color: Colors.grey.shade600),
                                const SizedBox(width: 4),
                                Text(
                                  '분리: ${_fmtDate(log.separatedAt!)}',
                                  style: const TextStyle(
                                      color: Color(0xFF888888), fontSize: 12),
                                ),
                              ],
                            ),
                          ],
                          if (log.memo != null && log.memo!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              log.memo!,
                              style: const TextStyle(
                                  color: Color(0xFF888888), fontSize: 12),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddSheet,
        backgroundColor: _kGreen,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ── Bottom Sheet ─────────────────────────────────────────────────────────────

class _BreedingLogSheet extends StatefulWidget {
  final String reptileId;
  final String sex;

  const _BreedingLogSheet({required this.reptileId, required this.sex});

  @override
  State<_BreedingLogSheet> createState() => _BreedingLogSheetState();
}

class _BreedingLogSheetState extends State<_BreedingLogSheet> {
  final _memoCtrl = TextEditingController();

  List<Map<String, dynamic>> _partners = [];
  String? _partnerId;
  DateTime _pairedAt = DateTime.now();
  DateTime? _separatedAt;
  bool? _success; // null = 미확인, true = 성공, false = 실패
  bool _isLoading = false;
  bool _partnersLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPartners();
  }

  @override
  void dispose() {
    _memoCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPartners() async {
    final partnerSex = widget.sex == 'male' ? 'female' : 'male';
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final data = await Supabase.instance.client
          .from('reptiles')
          .select('id, name')
          .eq('user_id', userId)
          .eq('sex', partnerSex)
          .inFilter('status', ['active', 'holdback'])
          .order('name');

      if (mounted) {
        setState(() {
          _partners = (data as List).cast<Map<String, dynamic>>();
          _partnersLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _partnersLoading = false);
    }
  }

  Future<void> _pickDate({required bool isSeparated}) async {
    final initial = isSeparated ? (_separatedAt ?? DateTime.now()) : _pairedAt;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: _kGreen,
            surface: Color(0xFF2A2A2A),
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isSeparated) {
        _separatedAt = picked;
      } else {
        _pairedAt = picked;
      }
    });
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);
    try {
      final payload = <String, dynamic>{
        'paired_at': _pairedAt.toUtc().toIso8601String(),
        if (_separatedAt != null)
          'separated_at': _separatedAt!.toUtc().toIso8601String(),
        if (_success != null) 'success': _success,
        if (_memoCtrl.text.trim().isNotEmpty) 'memo': _memoCtrl.text.trim(),
      };

      if (widget.sex == 'male') {
        payload['male_id'] = widget.reptileId;
        if (_partnerId != null) payload['female_id'] = _partnerId;
      } else {
        payload['female_id'] = widget.reptileId;
        if (_partnerId != null) payload['male_id'] = _partnerId;
      }

      await Supabase.instance.client.from('breeding_logs').insert(payload);

      if (mounted) Navigator.pop(context, true);
    } on PostgrestException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(e.message), backgroundColor: Colors.redAccent),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('저장 중 오류가 발생했습니다.'),
              backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _fmtDate(DateTime dt) =>
      '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final partnerLabel = widget.sex == 'male' ? '암컷 파트너' : '수컷 파트너';

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '메이팅 기록 추가',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // 파트너 드롭다운
            const Text('파트너',
                style: TextStyle(color: Color(0xFF888888), fontSize: 12)),
            const SizedBox(height: 6),
            _partnersLoading
                ? const SizedBox(
                    height: 48,
                    child: Center(
                        child: CircularProgressIndicator(
                            color: _kGreen, strokeWidth: 2)))
                : DropdownButtonFormField<String>(
                    initialValue: _partnerId,
                    hint: Text(partnerLabel,
                        style: const TextStyle(color: Color(0xFF666666))),
                    dropdownColor: _kCard,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF1A1A1A),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: const TextStyle(color: Colors.white),
                    items: _partners
                        .map((p) => DropdownMenuItem<String>(
                              value: p['id'] as String,
                              child: Text(p['name'] as String),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _partnerId = v),
                  ),
            const SizedBox(height: 16),

            // 교배일
            const Text('교배일',
                style: TextStyle(color: Color(0xFF888888), fontSize: 12)),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () => _pickDate(isSeparated: false),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today,
                        size: 16, color: Color(0xFF888888)),
                    const SizedBox(width: 10),
                    Text(
                      _fmtDate(_pairedAt),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 분리일 (선택)
            Row(
              children: [
                const Text('분리일 (선택)',
                    style: TextStyle(color: Color(0xFF888888), fontSize: 12)),
                const Spacer(),
                if (_separatedAt != null)
                  GestureDetector(
                    onTap: () => setState(() => _separatedAt = null),
                    child: const Text('지우기',
                        style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () => _pickDate(isSeparated: true),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.call_split,
                        size: 16, color: Color(0xFF888888)),
                    const SizedBox(width: 10),
                    Text(
                      _separatedAt != null
                          ? _fmtDate(_separatedAt!)
                          : '선택 안 함',
                      style: TextStyle(
                          color: _separatedAt != null
                              ? Colors.white
                              : const Color(0xFF666666)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 결과
            const Text('결과',
                style: TextStyle(color: Color(0xFF888888), fontSize: 12)),
            const SizedBox(height: 8),
            Row(
              children: [
                _successChip(null, '미확인'),
                const SizedBox(width: 8),
                _successChip(true, '성공'),
                const SizedBox(width: 8),
                _successChip(false, '실패'),
              ],
            ),
            const SizedBox(height: 16),

            // 메모
            const Text('메모',
                style: TextStyle(color: Color(0xFF888888), fontSize: 12)),
            const SizedBox(height: 6),
            TextField(
              controller: _memoCtrl,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF1A1A1A),
                hintText: '메모 (선택)',
                hintStyle: const TextStyle(color: Color(0xFF555555)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 저장 버튼
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kGreen,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _kGreen.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('저장',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _successChip(bool? value, String label) {
    final isSelected = _success == value;
    Color color;
    if (value == null) {
      color = const Color(0xFF888888);
    } else if (value) {
      color = _kGreen;
    } else {
      color = Colors.redAccent;
    }

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _success = value),
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.2) : const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? color : const Color(0xFF333333),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? color : const Color(0xFF888888),
                fontSize: 13,
                fontWeight:
                    isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
