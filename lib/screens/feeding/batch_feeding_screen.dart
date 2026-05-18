import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/feeding.dart';
import '../../services/notification_service.dart';

const _green = Color(0xFF4CAF82);
const _surface = Color(0xFF1E1E1E);

class BatchFeedingScreen extends StatefulWidget {
  const BatchFeedingScreen({super.key});

  @override
  State<BatchFeedingScreen> createState() => _BatchFeedingScreenState();
}

class _BatchFeedingScreenState extends State<BatchFeedingScreen> {
  FeedingStatus _status = FeedingStatus.fed;
  String? _recipeId;
  List<FeedingRecipe> _recipes = [];
  List<_ReptileItem> _reptiles = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final results = await Future.wait([
        Supabase.instance.client
            .from('feeding_recipes')
            .select()
            .eq('user_id', userId)
            .order('name'),
        Supabase.instance.client
            .from('reptiles')
            .select('id, name, morph, image_url, status, feeding_interval_days')
            .eq('user_id', userId)
            .or('status.eq.active,status.eq.holdback')
            .order('name'),
      ]);

      if (mounted) {
        setState(() {
          _recipes = (results[0] as List)
              .map((e) => FeedingRecipe.fromJson(e as Map<String, dynamic>))
              .toList();
          _reptiles = (results[1] as List).map((e) {
            final m = e as Map<String, dynamic>;
            return _ReptileItem(
              id: m['id'] as String,
              name: m['name'] as String,
              morph: m['morph'] as String?,
              imageUrl: m['image_url'] as String?,
              status: m['status'] as String,
              feedingIntervalDays: (m['feeding_interval_days'] as int?) ?? 7,
            );
          }).toList();
        });
      }
    } catch (e) {
      _snack('불러오기 실패: $e', error: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int get _selectedCount => _reptiles.where((r) => r.selected).length;
  bool get _allSelected =>
      _reptiles.isNotEmpty && _reptiles.every((r) => r.selected);

  void _toggleAll() {
    final next = !_allSelected;
    setState(() {
      for (final r in _reptiles) {
        r.selected = next;
      }
    });
  }

  Future<void> _save() async {
    final selected = _reptiles.where((r) => r.selected).toList();
    if (selected.isEmpty) {
      _snack('개체를 선택해주세요');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final now = DateTime.now();
      final rows = selected
          .map((r) => {
                'reptile_id': r.id,
                if (_recipeId != null) 'recipe_id': _recipeId,
                'fed_at': now.toIso8601String(),
                'status': _status.value,
              })
          .toList();

      await Supabase.instance.client.from('feeding_logs').insert(rows);

      // 다음 급여 알림 예약
      for (final r in selected) {
        final nextDate = now.add(Duration(days: r.feedingIntervalDays));
        await NotificationService.instance.scheduleFeeedingNotification(
          r.id, r.name, nextDate,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${selected.length}마리 급여 기록 완료'),
            backgroundColor: _green,
          ),
        );
        Navigator.pop(context, true);
      }
    } on PostgrestException catch (e) {
      _snack('저장 실패: ${e.message}', error: true);
    } catch (_) {
      _snack('저장 중 오류가 발생했습니다', error: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.redAccent : _green,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: _surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('일괄 급여 기록',
            style: TextStyle(color: Colors.white)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _green))
          : Column(
              children: [
                // ── 상단: 레시피 + 급여 상태 ─────────────────────────────
                Container(
                  color: const Color(0xFF1A1A1A),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 레시피 드롭다운
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 2),
                        decoration: BoxDecoration(
                          color: _surface,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String?>(
                            value: _recipeId,
                            isExpanded: true,
                            dropdownColor: const Color(0xFF2A2A2A),
                            icon: const Icon(Icons.keyboard_arrow_down,
                                color: Colors.grey),
                            hint: const Text('레시피 선택 (선택사항)',
                                style: TextStyle(
                                    color: Colors.grey, fontSize: 14)),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('없음',
                                    style:
                                        TextStyle(color: Colors.white)),
                              ),
                              ..._recipes.map((r) =>
                                  DropdownMenuItem<String?>(
                                    value: r.id,
                                    child: Text(r.name,
                                        style: const TextStyle(
                                            color: Colors.white)),
                                  )),
                            ],
                            onChanged: (v) =>
                                setState(() => _recipeId = v),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // 급여 상태 칩
                      Row(
                        children: FeedingStatus.values.map((s) {
                          final selected = _status == s;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _status = s),
                                child: AnimatedContainer(
                                  duration:
                                      const Duration(milliseconds: 150),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 10),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? s.color.withValues(alpha: 0.15)
                                        : _surface,
                                    borderRadius:
                                        BorderRadius.circular(8),
                                    border: Border.all(
                                      color: selected
                                          ? s.color
                                          : Colors.transparent,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    s.label,
                                    style: TextStyle(
                                      color: selected
                                          ? s.color
                                          : Colors.grey,
                                      fontWeight: selected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),

                // ── 전체선택 토글 ────────────────────────────────────────
                InkWell(
                  onTap: _toggleAll,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    color: const Color(0xFF181818),
                    child: Row(
                      children: [
                        Icon(
                          _allSelected
                              ? Icons.check_box
                              : Icons.check_box_outline_blank,
                          color: _allSelected ? _green : Colors.grey,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _allSelected ? '전체 해제' : '전체 선택',
                          style: TextStyle(
                            color: _allSelected ? _green : Colors.grey,
                            fontSize: 13,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${_reptiles.length}마리',
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── 개체 목록 ────────────────────────────────────────────
                Expanded(
                  child: _reptiles.isEmpty
                      ? Center(
                          child: Text(
                            '활성/홀드백 개체가 없습니다',
                            style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 15),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(
                              16, 8, 16, 100),
                          itemCount: _reptiles.length,
                          itemBuilder: (_, i) {
                            final r = _reptiles[i];
                            return GestureDetector(
                              onTap: () => setState(
                                  () => r.selected = !r.selected),
                              child: Container(
                                margin:
                                    const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: r.selected
                                      ? _green.withValues(alpha: 0.08)
                                      : _surface,
                                  borderRadius:
                                      BorderRadius.circular(12),
                                  border: Border.all(
                                    color: r.selected
                                        ? _green.withValues(alpha: 0.4)
                                        : Colors.transparent,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    // 체크박스
                                    Icon(
                                      r.selected
                                          ? Icons.check_circle
                                          : Icons.circle_outlined,
                                      color: r.selected
                                          ? _green
                                          : Colors.grey,
                                      size: 22,
                                    ),
                                    const SizedBox(width: 12),
                                    // 썸네일
                                    _Thumb(imageUrl: r.imageUrl),
                                    const SizedBox(width: 12),
                                    // 이름/모프
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            r.name,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 15,
                                              fontWeight:
                                                  FontWeight.w600,
                                            ),
                                          ),
                                          if (r.morph != null &&
                                              r.morph!.isNotEmpty)
                                            Text(
                                              r.morph!,
                                              style: const TextStyle(
                                                  color:
                                                      Color(0xFF888888),
                                                  fontSize: 12),
                                              overflow:
                                                  TextOverflow.ellipsis,
                                            ),
                                        ],
                                      ),
                                    ),
                                    // 상태 배지
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: r.status == 'holdback'
                                            ? const Color(0xFFFF9800)
                                                .withValues(alpha: 0.12)
                                            : _green.withValues(alpha: 0.12),
                                        borderRadius:
                                            BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        r.status == 'holdback'
                                            ? '홀드백'
                                            : '활성',
                                        style: TextStyle(
                                          color: r.status == 'holdback'
                                              ? const Color(0xFFFF9800)
                                              : _green,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: (_isSaving || _selectedCount == 0) ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
                disabledBackgroundColor: _green.withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white),
                    )
                  : Text(
                      '$_selectedCount마리 급여 기록하기',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  final String? imageUrl;
  const _Thumb({this.imageUrl});

  @override
  Widget build(BuildContext context) {
    if (imageUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          imageUrl!,
          width: 42,
          height: 42,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _placeholder(),
        ),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() => Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: _green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.pets_outlined, color: _green, size: 20),
      );
}

class _ReptileItem {
  final String id;
  final String name;
  final String? morph;
  final String? imageUrl;
  final String status;
  final int feedingIntervalDays;
  bool selected = false;

  _ReptileItem({
    required this.id,
    required this.name,
    this.morph,
    this.imageUrl,
    required this.status,
    this.feedingIntervalDays = 7,
  });
}
