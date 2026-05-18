import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/breeding.dart';
import '../../services/notification_service.dart';

const _kGreen = Color(0xFF4CAF82);
const _kSurface = Color(0xFF1E1E1E);
const _kCard = Color(0xFF2A2A2A);

class EggClutchScreen extends StatefulWidget {
  final String femaleId;
  final String femaleName;

  const EggClutchScreen({
    super.key,
    required this.femaleId,
    required this.femaleName,
  });

  @override
  State<EggClutchScreen> createState() => _EggClutchScreenState();
}

class _EggClutchScreenState extends State<EggClutchScreen> {
  List<EggClutch> _clutches = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final data = await Supabase.instance.client
          .from('egg_clutches')
          .select()
          .eq('female_id', widget.femaleId)
          .order('laid_at', ascending: false);

      if (mounted) {
        setState(() {
          _clutches = (data as List)
              .map((e) => EggClutch.fromJson(e as Map<String, dynamic>))
              .toList();
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showAddClutchSheet() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _kCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _EggClutchSheet(
        femaleId: widget.femaleId,
        femaleName: widget.femaleName,
      ),
    );
    if (result == true) _load();
  }

  Future<void> _showHatchSheet(EggClutch clutch) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _kCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _HatchRecordSheet(clutchId: clutch.id),
    );
    if (result == true) _load();
  }

  String _fmtDate(DateTime dt) =>
      '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';

  Widget _dDayBadge(EggClutch clutch) {
    if (clutch.expectedHatchDate == null) {
      return const SizedBox.shrink();
    }
    final d = clutch.dDay;
    String label;
    Color color;
    if (d > 0) {
      label = 'D-$d';
      color = _kGreen;
    } else if (d == 0) {
      label = 'D-Day';
      color = Colors.redAccent;
    } else {
      label = 'D+${-d}';
      color = const Color(0xFFFFA726);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: _kSurface,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '${widget.femaleName} · 산란 기록',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: _kGreen),
            onPressed: _showAddClutchSheet,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _kGreen))
          : _clutches.isEmpty
              ? const Center(
                  child: Text(
                    '산란 기록이 없어요',
                    style: TextStyle(color: Colors.grey, fontSize: 15),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _clutches.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final c = _clutches[i];
                    return GestureDetector(
                      onTap: () => _showHatchSheet(c),
                      child: Container(
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
                                  '산란일: ${_fmtDate(c.laidAt)}',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14),
                                ),
                                const Spacer(),
                                _dDayBadge(c),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                _eggStat('전체', c.totalEggs, Colors.white),
                                const SizedBox(width: 16),
                                _eggStat('유정란', c.fertile, _kGreen),
                                const SizedBox(width: 16),
                                _eggStat('무정란', c.infertile, Colors.redAccent),
                              ],
                            ),
                            if (c.expectedHatchDate != null) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.event,
                                      size: 13, color: Color(0xFF888888)),
                                  const SizedBox(width: 4),
                                  Text(
                                    '예상 해칭일: ${_fmtDate(c.expectedHatchDate!)}',
                                    style: const TextStyle(
                                        color: Color(0xFF888888),
                                        fontSize: 12),
                                  ),
                                ],
                              ),
                            ],
                            if (c.memo != null && c.memo!.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                c.memo!,
                                style: const TextStyle(
                                    color: Color(0xFF888888), fontSize: 12),
                              ),
                            ],
                            const SizedBox(height: 8),
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Icon(Icons.touch_app,
                                    size: 13, color: Color(0xFF555555)),
                                SizedBox(width: 4),
                                Text(
                                  '탭하여 해칭 기록 추가',
                                  style: TextStyle(
                                      color: Color(0xFF555555), fontSize: 11),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddClutchSheet,
        backgroundColor: _kGreen,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _eggStat(String label, int count, Color color) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xFF888888), fontSize: 11),
          ),
          Text(
            '$count개',
            style: TextStyle(
                color: color, fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ],
      );
}

// ── 산란 추가 Sheet ────────────────────────────────────────────────────────────

class _EggClutchSheet extends StatefulWidget {
  final String femaleId;
  final String femaleName;
  const _EggClutchSheet({required this.femaleId, required this.femaleName});

  @override
  State<_EggClutchSheet> createState() => _EggClutchSheetState();
}

class _EggClutchSheetState extends State<_EggClutchSheet> {
  final _totalCtrl = TextEditingController();
  final _fertileCtrl = TextEditingController();
  final _memoCtrl = TextEditingController();

  DateTime _laidAt = DateTime.now();
  DateTime? _expectedHatchDate;
  String? _breedingLogId;
  List<Map<String, dynamic>> _breedingLogs = [];
  bool _isLoading = false;
  bool _logsLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBreedingLogs();
  }

  @override
  void dispose() {
    _totalCtrl.dispose();
    _fertileCtrl.dispose();
    _memoCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBreedingLogs() async {
    try {
      final data = await Supabase.instance.client
          .from('breeding_logs')
          .select('id, paired_at, male:reptiles!male_id(name)')
          .eq('female_id', widget.femaleId)
          .eq('success', true)
          .order('paired_at', ascending: false);

      if (mounted) {
        setState(() {
          _breedingLogs = (data as List).cast<Map<String, dynamic>>();
          _logsLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _logsLoading = false);
    }
  }

  Future<void> _pickDate({required bool isHatch}) async {
    final initial = isHatch ? (_expectedHatchDate ?? DateTime.now()) : _laidAt;
    final last = isHatch
        ? DateTime.now().add(const Duration(days: 365))
        : DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: last,
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
      if (isHatch) {
        _expectedHatchDate = picked;
      } else {
        _laidAt = picked;
      }
    });
  }

  void _autoCalcHatchDate() {
    setState(() {
      _expectedHatchDate = _laidAt.add(const Duration(days: 60));
    });
  }

  Future<void> _save() async {
    final totalText = _totalCtrl.text.trim();
    final fertileText = _fertileCtrl.text.trim();
    if (totalText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('전체 알 수를 입력해주세요.'),
            backgroundColor: Colors.redAccent),
      );
      return;
    }
    final total = int.tryParse(totalText) ?? 0;
    final fertile = int.tryParse(fertileText) ?? 0;
    if (fertile > total) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('유정란 수는 전체 알 수보다 클 수 없어요.'),
            backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final payload = <String, dynamic>{
        'female_id': widget.femaleId,
        'laid_at':
            '${_laidAt.year}-${_laidAt.month.toString().padLeft(2, '0')}-${_laidAt.day.toString().padLeft(2, '0')}',
        'total_eggs': total,
        'fertile': fertile,
        'infertile': total - fertile,
        if (_breedingLogId != null) 'breeding_log_id': _breedingLogId,
        if (_expectedHatchDate != null)
          'expected_hatch_date':
              '${_expectedHatchDate!.year}-${_expectedHatchDate!.month.toString().padLeft(2, '0')}-${_expectedHatchDate!.day.toString().padLeft(2, '0')}',
        if (_memoCtrl.text.trim().isNotEmpty) 'memo': _memoCtrl.text.trim(),
      };

      final result = await Supabase.instance.client
          .from('egg_clutches')
          .insert(payload)
          .select('id')
          .single();

      if (_expectedHatchDate != null) {
        await NotificationService.instance.scheduleHatchingNotification(
          result['id'] as String,
          widget.femaleName,
          _expectedHatchDate!,
        );
      }

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

  String _logLabel(Map<String, dynamic> log) {
    final dt = DateTime.parse(log['paired_at'] as String).toLocal();
    final maleName =
        (log['male'] as Map<String, dynamic>?)?['name'] as String?;
    final dateStr = _fmtDate(dt);
    return maleName != null ? '$dateStr · $maleName' : dateStr;
  }

  InputDecoration _inputDeco(String hint) => InputDecoration(
        filled: true,
        fillColor: const Color(0xFF1A1A1A),
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF555555)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      );

  @override
  Widget build(BuildContext context) {
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
              '산란 기록 추가',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // 산란일
            const Text('산란일',
                style: TextStyle(color: Color(0xFF888888), fontSize: 12)),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () => _pickDate(isHatch: false),
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
                    Text(_fmtDate(_laidAt),
                        style: const TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 알 수
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('전체 알 수 *',
                          style:
                              TextStyle(color: Color(0xFF888888), fontSize: 12)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _totalCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDeco('예: 8'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('유정란 수',
                          style:
                              TextStyle(color: Color(0xFF888888), fontSize: 12)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _fertileCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDeco('예: 6'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 연관 메이팅 기록
            const Text('연관 메이팅 기록 (선택)',
                style: TextStyle(color: Color(0xFF888888), fontSize: 12)),
            const SizedBox(height: 6),
            _logsLoading
                ? const SizedBox(
                    height: 48,
                    child: Center(
                        child: CircularProgressIndicator(
                            color: _kGreen, strokeWidth: 2)))
                : DropdownButtonFormField<String>(
                    initialValue: _breedingLogId,
                    hint: const Text('선택 안 함',
                        style: TextStyle(color: Color(0xFF666666))),
                    dropdownColor: _kCard,
                    decoration: _inputDeco(''),
                    style: const TextStyle(color: Colors.white),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('선택 안 함',
                            style: TextStyle(color: Color(0xFF888888))),
                      ),
                      ..._breedingLogs.map((log) => DropdownMenuItem<String>(
                            value: log['id'] as String,
                            child: Text(_logLabel(log),
                                overflow: TextOverflow.ellipsis),
                          )),
                    ],
                    onChanged: (v) => setState(() => _breedingLogId = v),
                  ),
            const SizedBox(height: 16),

            // 예상 해칭일
            Row(
              children: [
                const Text('예상 해칭일 (선택)',
                    style:
                        TextStyle(color: Color(0xFF888888), fontSize: 12)),
                const Spacer(),
                GestureDetector(
                  onTap: _autoCalcHatchDate,
                  child: const Text(
                    '산란일 +60일',
                    style: TextStyle(color: _kGreen, fontSize: 12),
                  ),
                ),
                if (_expectedHatchDate != null) ...[
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => setState(() => _expectedHatchDate = null),
                    child: const Text('지우기',
                        style:
                            TextStyle(color: Colors.redAccent, fontSize: 12)),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () => _pickDate(isHatch: true),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.egg_outlined,
                        size: 16, color: Color(0xFF888888)),
                    const SizedBox(width: 10),
                    Text(
                      _expectedHatchDate != null
                          ? _fmtDate(_expectedHatchDate!)
                          : '선택 안 함',
                      style: TextStyle(
                          color: _expectedHatchDate != null
                              ? Colors.white
                              : const Color(0xFF666666)),
                    ),
                  ],
                ),
              ),
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
              decoration: _inputDeco('메모 (선택)'),
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
}

// ── 해칭 기록 Sheet ────────────────────────────────────────────────────────────

class _HatchRecordSheet extends StatefulWidget {
  final String clutchId;
  const _HatchRecordSheet({required this.clutchId});

  @override
  State<_HatchRecordSheet> createState() => _HatchRecordSheetState();
}

class _HatchRecordSheetState extends State<_HatchRecordSheet> {
  final _countCtrl = TextEditingController();
  final _memoCtrl = TextEditingController();
  DateTime _hatchedAt = DateTime.now();
  bool _isLoading = false;

  @override
  void dispose() {
    _countCtrl.dispose();
    _memoCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _hatchedAt,
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
    if (picked != null) setState(() => _hatchedAt = picked);
  }

  Future<void> _save() async {
    final countText = _countCtrl.text.trim();
    if (countText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('해칭 수를 입력해주세요.'),
            backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.from('hatch_records').insert({
        'clutch_id': widget.clutchId,
        'hatched_at':
            '${_hatchedAt.year}-${_hatchedAt.month.toString().padLeft(2, '0')}-${_hatchedAt.day.toString().padLeft(2, '0')}',
        'hatched_count': int.tryParse(countText) ?? 0,
        if (_memoCtrl.text.trim().isNotEmpty) 'memo': _memoCtrl.text.trim(),
      });

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
              '해칭 기록 추가',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // 해칭일
            const Text('해칭일',
                style: TextStyle(color: Color(0xFF888888), fontSize: 12)),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: _pickDate,
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
                    Text(_fmtDate(_hatchedAt),
                        style: const TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 해칭 수
            const Text('해칭 수 *',
                style: TextStyle(color: Color(0xFF888888), fontSize: 12)),
            const SizedBox(height: 6),
            TextField(
              controller: _countCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF1A1A1A),
                hintText: '예: 5',
                hintStyle: const TextStyle(color: Color(0xFF555555)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
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
}
