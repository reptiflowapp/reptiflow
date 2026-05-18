import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/feeding.dart';

const _green = Color(0xFF4CAF82);
const _surface = Color(0xFF1E1E1E);

class FeedingHistoryWidget extends StatefulWidget {
  final String reptileId;
  const FeedingHistoryWidget({super.key, required this.reptileId});

  @override
  State<FeedingHistoryWidget> createState() => _FeedingHistoryWidgetState();
}

class _FeedingHistoryWidgetState extends State<FeedingHistoryWidget> {
  List<_LogRow> _rows = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _delete(String logId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text('급여 기록 삭제',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        content: const Text('이 급여 기록을 삭제할까요?',
            style: TextStyle(color: Colors.grey)),
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
    try {
      await Supabase.instance.client
          .from('feeding_logs')
          .delete()
          .eq('id', logId);
      _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('삭제 실패'),
              backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final data = await Supabase.instance.client
          .from('feeding_logs')
          .select('*, feeding_recipes(name)')
          .eq('reptile_id', widget.reptileId)
          .order('fed_at', ascending: false)
          .limit(10);

      if (mounted) {
        setState(() {
          _rows = (data as List).map((e) {
            final m = e as Map<String, dynamic>;
            final recipeName =
                (m['feeding_recipes'] as Map<String, dynamic>?)?['name']
                    as String?;
            return _LogRow(
              log: FeedingLog.fromJson(m),
              recipeName: recipeName,
            );
          }).toList();
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _fmtDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(d).inDays;
    if (diff == 0) return '오늘';
    if (diff == 1) return '어제';
    return '${dt.month}.${dt.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator(color: _green)),
      );
    }

    if (_rows.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Center(
          child: Text(
            '아직 급여 기록이 없어요',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ),
      );
    }

    return Column(
      children: _rows.asMap().entries.map((entry) {
        final i = entry.key;
        final row = entry.value;
        final log = row.log;
        return Container(
          margin: EdgeInsets.only(bottom: i < _rows.length - 1 ? 8 : 0),
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              // 날짜
              SizedBox(
                width: 36,
                child: Text(
                  _fmtDate(log.fedAt),
                  style: const TextStyle(
                      color: Color(0xFF888888), fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 10),
              // 상태 칩
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: log.status.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: log.status.color.withValues(alpha: 0.35)),
                ),
                child: Text(
                  log.status.label,
                  style: TextStyle(
                      color: log.status.color,
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 10),
              // 레시피명 / 메모
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (row.recipeName != null)
                      Text(
                        row.recipeName!,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (log.memo != null && log.memo!.isNotEmpty)
                      Text(
                        log.memo!,
                        style: const TextStyle(
                            color: Color(0xFF888888), fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (row.recipeName == null &&
                        (log.memo == null || log.memo!.isEmpty))
                      const Text(
                        '-',
                        style: TextStyle(
                            color: Color(0xFF555555), fontSize: 13),
                      ),
                  ],
                ),
              ),
              // 시간
              Text(
                '${log.fedAt.hour.toString().padLeft(2, '0')}:${log.fedAt.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(
                    color: Color(0xFF555555), fontSize: 11),
              ),
              // 삭제 버튼
              GestureDetector(
                onTap: () => _delete(log.id),
                child: const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(Icons.delete_outline,
                      color: Colors.redAccent, size: 18),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _LogRow {
  final FeedingLog log;
  final String? recipeName;
  _LogRow({required this.log, this.recipeName});
}
