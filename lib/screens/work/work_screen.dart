import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../feeding/batch_feeding_screen.dart';
import '../feeding/recipe_screen.dart';
import 'voice_work_screen.dart';

const _green = Color(0xFF4CAF82);
const _surface = Color(0xFF1E1E1E);

class WorkScreen extends StatefulWidget {
  const WorkScreen({super.key});

  @override
  State<WorkScreen> createState() => _WorkScreenState();
}

class _WorkScreenState extends State<WorkScreen> {
  int _fedToday = 0;
  int _unrecordedToday = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final now = DateTime.now();
      final todayStart =
          DateTime(now.year, now.month, now.day).toIso8601String();
      final todayEnd =
          DateTime(now.year, now.month, now.day, 23, 59, 59).toIso8601String();

      final results = await Future.wait([
        // 활성/홀드백 개체 전체
        Supabase.instance.client
            .from('reptiles')
            .select('id')
            .eq('user_id', userId)
            .or('status.eq.active,status.eq.holdback'),
        // 오늘 급여완료 기록
        Supabase.instance.client
            .from('feeding_logs')
            .select('reptile_id')
            .gte('fed_at', todayStart)
            .lte('fed_at', todayEnd)
            .eq('status', 'fed'),
      ]);

      final allIds = (results[0] as List)
          .map((e) => (e as Map<String, dynamic>)['id'] as String)
          .toSet();
      final fedIds = (results[1] as List)
          .map((e) => (e as Map<String, dynamic>)['reptile_id'] as String)
          .toSet();

      if (mounted) {
        setState(() {
          _fedToday = fedIds.intersection(allIds).length;
          _unrecordedToday = allIds.difference(fedIds).length;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: RefreshIndicator(
        onRefresh: _load,
        color: _green,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 100),
          children: [
            const Text(
              '작업',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '급여 기록 및 관리',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 24),

            // ── 음성 작업 시작 ──────────────────────────────────────────
            _WorkCard(
              icon: Icons.mic,
              title: '음성 작업 시작',
              subtitle: '말로 기록하세요 — 호돌이 급여완료, 투루 거부 등',
              color: _green,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const VoiceWorkScreen()),
              ).then((_) => _load()),
            ),
            const SizedBox(height: 12),

            // ── 일괄 급여 기록 ──────────────────────────────────────────
            _WorkCard(
              icon: Icons.playlist_add_check_outlined,
              title: '일괄 급여 기록',
              subtitle: '여러 개체를 한 번에 급여 기록',
              color: _green,
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const BatchFeedingScreen(),
                  ),
                );
                _load();
              },
            ),
            const SizedBox(height: 12),

            // ── 레시피 관리 ──────────────────────────────────────────────
            _WorkCard(
              icon: Icons.restaurant_menu_outlined,
              title: '레시피 관리',
              subtitle: '급여 레시피 추가·수정·삭제',
              color: const Color(0xFFFFA726),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RecipeScreen()),
              ),
            ),
            const SizedBox(height: 12),

            // ── 오늘 급여 현황 ───────────────────────────────────────────
            _TodayStatusCard(
              isLoading: _isLoading,
              fedCount: _fedToday,
              unrecordedCount: _unrecordedToday,
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const BatchFeedingScreen(),
                  ),
                );
                _load();
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── 작업 카드 ─────────────────────────────────────────────────────────────────

class _WorkCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _WorkCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                        color: Color(0xFF888888), fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }
}

// ── 오늘 급여 현황 카드 ────────────────────────────────────────────────────────

class _TodayStatusCard extends StatelessWidget {
  final bool isLoading;
  final int fedCount;
  final int unrecordedCount;
  final VoidCallback onTap;

  const _TodayStatusCard({
    required this.isLoading,
    required this.fedCount,
    required this.unrecordedCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF42A5F5).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.bar_chart_outlined,
                      color: Color(0xFF42A5F5), size: 24),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '오늘 급여 현황',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        '탭하면 일괄 급여 기록으로 이동',
                        style: TextStyle(
                            color: Color(0xFF888888), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
              ],
            ),
            const SizedBox(height: 16),
            isLoading
                ? const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: _green),
                    ),
                  )
                : Row(
                    children: [
                      _StatChip(
                        label: '급여완료',
                        count: fedCount,
                        color: _green,
                      ),
                      const SizedBox(width: 10),
                      _StatChip(
                        label: '미기록',
                        count: unrecordedCount,
                        color: const Color(0xFF888888),
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatChip({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(color: color, fontSize: 12),
          ),
          const SizedBox(width: 6),
          Text(
            '$count마리',
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
