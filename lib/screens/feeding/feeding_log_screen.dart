import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/feeding.dart';
import '../../services/notification_service.dart';

const _green = Color(0xFF4CAF82);
const _surface = Color(0xFF1E1E1E);

class FeedingLogScreen extends StatefulWidget {
  final String reptileId;
  final String reptileName;
  final int feedingIntervalDays;

  const FeedingLogScreen({
    super.key,
    required this.reptileId,
    required this.reptileName,
    this.feedingIntervalDays = 7,
  });

  @override
  State<FeedingLogScreen> createState() => _FeedingLogScreenState();
}

class _FeedingLogScreenState extends State<FeedingLogScreen> {
  FeedingStatus _status = FeedingStatus.fed;
  String? _recipeId;
  List<FeedingRecipe> _recipes = [];
  DateTime _fedAt = DateTime.now();
  final _memoCtrl = TextEditingController();
  bool _isLoading = false;
  bool _recipesLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecipes();
  }

  @override
  void dispose() {
    _memoCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRecipes() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final data = await Supabase.instance.client
          .from('feeding_recipes')
          .select()
          .eq('user_id', userId)
          .order('name');
      if (mounted) {
        setState(() {
          _recipes = (data as List)
              .map((e) => FeedingRecipe.fromJson(e as Map<String, dynamic>))
              .toList();
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _recipesLoading = false);
    }
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _fedAt,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: _green,
            surface: Color(0xFF2A2A2A),
          ),
        ),
        child: child!,
      ),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_fedAt),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: _green,
            surface: Color(0xFF2A2A2A),
          ),
        ),
        child: child!,
      ),
    );
    if (!mounted) return;
    setState(() {
      _fedAt = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? _fedAt.hour,
        time?.minute ?? _fedAt.minute,
      );
    });
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);
    try {
      final log = FeedingLog(
        id: '',
        reptileId: widget.reptileId,
        recipeId: _recipeId,
        fedAt: _fedAt,
        status: _status,
        memo: _memoCtrl.text.trim().isEmpty ? null : _memoCtrl.text.trim(),
        createdAt: DateTime.now(),
      );
      await Supabase.instance.client
          .from('feeding_logs')
          .insert(log.toJson());

      // 다음 급여 알림 예약
      final nextDate = _fedAt.add(Duration(days: widget.feedingIntervalDays));
      await NotificationService.instance.scheduleFeeedingNotification(
        widget.reptileId, widget.reptileName, nextDate,
      );

      if (mounted) Navigator.pop(context, true);
    } on PostgrestException catch (e) {
      _snack('저장 실패: ${e.message}', error: true);
    } catch (_) {
      _snack('저장 중 오류가 발생했습니다', error: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.redAccent : _green,
    ));
  }

  String _fmtDateTime(DateTime dt) {
    final d = '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
    final t = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    return '$d $t';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: _surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('급여 기록',
                style: TextStyle(color: Colors.white, fontSize: 16)),
            Text(
              widget.reptileName,
              style: const TextStyle(color: _green, fontSize: 12),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── 급여 상태 ────────────────────────────────────────────────
          const _Label('급여 상태'),
          const SizedBox(height: 10),
          Row(
            children: FeedingStatus.values.map((s) {
              final selected = _status == s;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _status = s),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        color: selected
                            ? s.color.withValues(alpha: 0.15)
                            : _surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected ? s.color : Colors.transparent,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        s.label,
                        style: TextStyle(
                          color: selected ? s.color : Colors.grey,
                          fontWeight: selected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // ── 레시피 선택 ──────────────────────────────────────────────
          const _Label('레시피'),
          const SizedBox(height: 10),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: _recipesLoading
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Center(
                      child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: _green)),
                    ),
                  )
                : DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: _recipeId,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF2A2A2A),
                      icon: const Icon(Icons.keyboard_arrow_down,
                          color: Colors.grey),
                      hint: const Text('없음',
                          style: TextStyle(color: Colors.grey)),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('없음',
                              style: TextStyle(color: Colors.white)),
                        ),
                        ..._recipes.map((r) => DropdownMenuItem<String?>(
                              value: r.id,
                              child: Text(r.name,
                                  style:
                                      const TextStyle(color: Colors.white)),
                            )),
                      ],
                      onChanged: (v) => setState(() => _recipeId = v),
                    ),
                  ),
          ),
          const SizedBox(height: 24),

          // ── 날짜/시간 ────────────────────────────────────────────────
          const _Label('날짜 / 시간'),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _pickDateTime,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.access_time_outlined,
                      color: Colors.grey, size: 18),
                  const SizedBox(width: 12),
                  Text(
                    _fmtDateTime(_fedAt),
                    style: const TextStyle(
                        color: Colors.white, fontSize: 15),
                  ),
                  const Spacer(),
                  const Icon(Icons.chevron_right,
                      color: Colors.grey, size: 18),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ── 메모 ─────────────────────────────────────────────────────
          const _Label('메모'),
          const SizedBox(height: 10),
          TextField(
            controller: _memoCtrl,
            style: const TextStyle(color: Colors.white),
            maxLines: 3,
            decoration: InputDecoration(
              hintText: '메모를 입력하세요 (선택)',
              hintStyle: const TextStyle(color: Color(0xFF555555)),
              filled: true,
              fillColor: _surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _green),
              ),
            ),
          ),
          const SizedBox(height: 32),

          // ── 저장 버튼 ────────────────────────────────────────────────
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
                disabledBackgroundColor: _green.withValues(alpha: 0.4),
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
                  : const Text('급여 기록 저장',
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

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
            color: Colors.grey, fontSize: 12, letterSpacing: 0.5),
      );
}
