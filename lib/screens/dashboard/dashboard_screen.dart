import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../feeding/batch_feeding_screen.dart';


class DashboardScreen extends StatefulWidget {
  final VoidCallback? onGoToRacks;
  const DashboardScreen({super.key, this.onGoToRacks});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const _green = Color(0xFF4CAF82);

  bool _isLoading = true;
  bool _showInactive = false;
  bool _showDeceased = false;

  int _total = 0;
  int _female = 0;
  int _male = 0;
  int _baby = 0;
  int _owned = 0;    // active + holdback
  int _available = 0;
  int _sold = 0;
  int _deceased = 0;
  int _placed = 0;
  int _unplaced = 0; // owned not in rack_slots

  List<Map<String, dynamic>> _recentReptiles = [];

  int _feedingDue = 0;
  int _refusedCount = 0;
  int _layingDue = 0;
  int _hatchingSoon = 0;
  String _soonestDDay = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final client = Supabase.instance.client;
      final results = await Future.wait([
        client
            .from('reptiles')
            .select('id, sex, status, name, morph, image_url, feeding_interval_days')
            .order('created_at', ascending: false),
        client
            .from('rack_slots')
            .select('reptile_id')
            .not('reptile_id', 'is', null),
        client
            .from('feeding_logs')
            .select('reptile_id, status, fed_at')
            .order('fed_at', ascending: false)
            .limit(500),
        client
            .from('breeding_logs')
            .select('female_id')
            .eq('success', true),
        client
            .from('egg_clutches')
            .select('female_id, expected_hatch_date'),
      ]);

      final reptiles = results[0] as List;
      final slots = results[1] as List;
      final feedingLogs = results[2] as List;
      final successBreedings = results[3] as List;
      final eggClutches = results[4] as List;

      final placedIds = slots
          .map((s) => (s as Map<String, dynamic>)['reptile_id'] as String)
          .toSet();

      // 활성/홀드백 reptile ID 집합
      final activeIds = reptiles.where((r) {
        final s = (r as Map<String, dynamic>)['status'] as String;
        return s == 'active' || s == 'holdback';
      }).map((r) => (r as Map<String, dynamic>)['id'] as String).toSet();

      // 개체별 마지막 급여일 맵
      final latestFedAt = <String, DateTime>{};
      for (final l in feedingLogs) {
        final m = l as Map<String, dynamic>;
        final rid = m['reptile_id'] as String;
        final fedAt = DateTime.parse(m['fed_at'] as String);
        if (!latestFedAt.containsKey(rid) || fedAt.isAfter(latestFedAt[rid]!)) {
          latestFedAt[rid] = fedAt;
        }
      }

      // 급여 예정: 마지막 급여일로부터 feeding_interval_days 이상 지난 개체
      final now = DateTime.now();
      int feedingDue = 0;
      for (final r in reptiles) {
        final m = r as Map<String, dynamic>;
        final status = m['status'] as String;
        if (status != 'active' && status != 'holdback') continue;
        final id = m['id'] as String;
        final intervalDays = (m['feeding_interval_days'] as int?) ?? 7;
        final lastFed = latestFedAt[id];
        if (lastFed == null || now.difference(lastFed).inDays >= intervalDays) {
          feedingDue++;
        }
      }

      // 거부중: 최근 3개 기록이 모두 refused인 개체 수
      final logsByReptile = <String, List<String>>{};
      for (final l in feedingLogs) {
        final m = l as Map<String, dynamic>;
        final rid = m['reptile_id'] as String;
        if (!activeIds.contains(rid)) continue;
        logsByReptile.putIfAbsent(rid, () => []).add(m['status'] as String);
      }
      final refusedCount = logsByReptile.values.where((logs) {
        final last3 = logs.take(3).toList();
        return last3.length == 3 && last3.every((s) => s == 'refused');
      }).length;

      // 산란 예정: 성공한 브리딩 기록이 있는 암컷 중 아직 산란 기록 없는 활성 개체
      final successFemaleIds = successBreedings
          .map((e) => (e as Map<String, dynamic>)['female_id'] as String?)
          .whereType<String>()
          .toSet();
      final clutchFemaleIds = eggClutches
          .map((e) => (e as Map<String, dynamic>)['female_id'] as String)
          .toSet();
      final activeFemaleIds = reptiles.where((r) {
        final m = r as Map<String, dynamic>;
        final s = m['status'] as String;
        return (s == 'active' || s == 'holdback') && m['sex'] == 'female';
      }).map((r) => (r as Map<String, dynamic>)['id'] as String).toSet();
      final layingDue = successFemaleIds
          .where((id) => !clutchFemaleIds.contains(id) && activeFemaleIds.contains(id))
          .length;

      // 해칭 예정: expected_hatch_date가 오늘~14일 내인 clutch 수
      final today = DateTime(now.year, now.month, now.day);
      final in14 = today.add(const Duration(days: 14));
      final hatchingClutches = eggClutches.where((e) {
        final raw = (e as Map<String, dynamic>)['expected_hatch_date'] as String?;
        if (raw == null) return false;
        final d = DateTime.parse(raw);
        return !d.isBefore(today) && !d.isAfter(in14);
      }).toList();
      final hatchingSoon = hatchingClutches.length;

      String soonestDDay = '';
      if (hatchingClutches.isNotEmpty) {
        final earliest = hatchingClutches
            .map((e) => DateTime.parse(
                (e as Map<String, dynamic>)['expected_hatch_date'] as String))
            .reduce((a, b) => a.isBefore(b) ? a : b);
        final diff = earliest.difference(today).inDays;
        soonestDDay = diff == 0 ? 'D-Day' : 'D-$diff';
      }

      if (mounted) {
        setState(() {
          _total = reptiles.length;
          _female =
              reptiles.where((r) => (r as Map)['sex'] == 'female').length;
          _male = reptiles.where((r) => (r as Map)['sex'] == 'male').length;
          _baby =
              reptiles.where((r) => (r as Map)['sex'] == 'unknown').length;
          _owned = activeIds.length;
          _available = reptiles
              .where((r) => (r as Map)['status'] == 'available')
              .length;
          _sold =
              reptiles.where((r) => (r as Map)['status'] == 'sold').length;
          _deceased =
              reptiles.where((r) => (r as Map)['status'] == 'deceased').length;
          _placed = placedIds.length;
          _unplaced = reptiles.where((r) {
            final s = (r as Map)['status'] as String;
            final id = (r as Map)['id'] as String;
            return (s == 'active' || s == 'holdback') &&
                !placedIds.contains(id);
          }).length;
          _recentReptiles = reptiles
              .take(5)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          _feedingDue = feedingDue;
          _refusedCount = refusedCount;
          _layingDue = layingDue;
          _hatchingSoon = hatchingSoon;
          _soonestDDay = soonestDDay;
        });
      }
    } catch (_) {
      // 오류 시 0으로 표시
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      color: _green,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
        children: [
          // ── 오늘 할 일 ───────────────────────────────────────────────
          const _SectionHeader('오늘 할 일'),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _TaskCard(
                  icon: Icons.restaurant_outlined,
                  label: '급여 예정',
                  color: const Color(0xFF4CAF82),
                  count: _isLoading ? null : _feedingDue,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const BatchFeedingScreen()),
                  ).then((_) => _load()),
                ),
                const SizedBox(width: 10),
                _TaskCard(
                  icon: Icons.warning_amber_outlined,
                  label: '거부중',
                  color: const Color(0xFFEF5350),
                  count: _isLoading ? null : _refusedCount,
                ),
                const SizedBox(width: 10),
                _TaskCard(
                  icon: Icons.egg_outlined,
                  label: '산란 예정',
                  color: const Color(0xFFFFA726),
                  count: _isLoading ? null : _layingDue,
                ),
                const SizedBox(width: 10),
                _TaskCard(
                  icon: Icons.water_drop_outlined,
                  label: '해칭 예정',
                  color: const Color(0xFF42A5F5),
                  count: _isLoading ? null : _hatchingSoon,
                  subtitle: _hatchingSoon > 0 ? _soonestDDay : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // ── 개체 현황 (4개 가로 한 줄) ───────────────────────────────
          const _SectionHeader('개체 현황'),
          const SizedBox(height: 10),
          _isLoading
              ? const _LoadingPlaceholder(height: 80)
              : Row(
                  children: [
                    Expanded(
                      child: _MiniStatCard(
                        icon: Icons.pets_outlined,
                        label: '전체',
                        count: _total,
                        color: _green,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MiniStatCard(
                        symbol: '♀',
                        label: '암컷',
                        count: _female,
                        color: const Color(0xFFF48FB1),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MiniStatCard(
                        symbol: '♂',
                        label: '수컷',
                        count: _male,
                        color: const Color(0xFF42A5F5),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MiniStatCard(
                        symbol: '?',
                        label: '미상',
                        count: _baby,
                        color: const Color(0xFFFFCC02),
                      ),
                    ),
                  ],
                ),
          const SizedBox(height: 28),

          // ── 최근 등록 개체 ────────────────────────────────────────────
          const _SectionHeader('최근 등록 개체'),
          const SizedBox(height: 10),
          _isLoading
              ? const _LoadingPlaceholder(height: 110)
              : _recentReptiles.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: Text(
                          '등록된 개체가 없습니다',
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 13),
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _recentReptiles
                            .map(
                              (r) => Padding(
                                padding: const EdgeInsets.only(right: 10),
                                child: _RecentReptileCard(reptile: r),
                              ),
                            )
                            .toList(),
                      ),
                    ),
          const SizedBox(height: 28),

          // ── 스마트 그룹 ──────────────────────────────────────────────
          const _SectionHeader('스마트 그룹'),
          const SizedBox(height: 10),
          if (!_isLoading) ...[
            _GroupCard(
              icon: Icons.check_circle_outline,
              label: '전체 보유 개체',
              count: _owned,
              color: _green,
            ),
            const SizedBox(height: 8),
            _GroupCard(
              icon: Icons.storefront_outlined,
              label: '분양가능 개체',
              count: _available,
              color: const Color(0xFF42A5F5),
            ),
            const SizedBox(height: 8),
            _GroupCard(
              icon: Icons.grid_view_outlined,
              label: '렉 배치 개체',
              count: _placed,
              color: _green,
            ),
            const SizedBox(height: 8),
            _GroupCard(
              icon: Icons.grid_off_outlined,
              label: '렉 미배치 개체',
              count: _unplaced,
              color: const Color(0xFF888888),
            ),
            const SizedBox(height: 10),

            // 비활성 개체 토글
            _ToggleRow(
              label: '비활성 개체',
              count: _sold + _deceased,
              isExpanded: _showInactive,
              onToggle: () => setState(() {
                _showInactive = !_showInactive;
                if (!_showInactive) _showDeceased = false;
              }),
            ),
            if (_showInactive) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Column(
                  children: [
                    _GroupCard(
                      icon: Icons.sell_outlined,
                      label: '분양 보낸 개체',
                      count: _sold,
                      color: const Color(0xFFFFA726),
                    ),
                    const SizedBox(height: 8),

                    // ♥ 개체 토글
                    _ToggleRow(
                      label: '♥ 개체',
                      count: _deceased,
                      isExpanded: _showDeceased,
                      onToggle: () =>
                          setState(() => _showDeceased = !_showDeceased),
                      subtle: true,
                    ),
                    if (_showDeceased) ...[
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: _GroupCard(
                          icon: Icons.favorite_border,
                          label: '무지개다리',
                          count: _deceased,
                          color: const Color(0xFF666666),
                          small: true,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

// ── Section Header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) => Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      );
}

// ── Mini Stat Card (4개 가로 한 줄) ──────────────────────────────────────────

class _MiniStatCard extends StatelessWidget {
  final String? symbol;
  final IconData? icon;
  final String label;
  final int count;
  final Color color;

  const _MiniStatCard({
    this.symbol,
    this.icon,
    required this.label,
    required this.count,
    required this.color,
  }) : assert(symbol != null || icon != null);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          icon != null
              ? Icon(icon, color: color, size: 16)
              : Text(
                  symbol!,
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
          const SizedBox(height: 3),
          Text(
            '$count',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Color(0xFF888888), fontSize: 10),
          ),
        ],
      ),
    );
  }
}

// ── Recent Reptile Card ───────────────────────────────────────────────────────

class _RecentReptileCard extends StatelessWidget {
  final Map<String, dynamic> reptile;
  const _RecentReptileCard({required this.reptile});

  @override
  Widget build(BuildContext context) {
    final name = reptile['name'] as String? ?? '';
    final morph = reptile['morph'] as String? ?? '';
    final imageUrl = reptile['image_url'] as String?;
    final sex = reptile['sex'] as String? ?? 'unknown';

    final sexColor = sex == 'male'
        ? const Color(0xFF42A5F5)
        : sex == 'female'
            ? const Color(0xFFF48FB1)
            : Colors.grey;
    final sexSymbol = sex == 'male'
        ? '♂'
        : sex == 'female'
            ? '♀'
            : '?';

    return Container(
      width: 90,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // 사진 or 성별 아이콘
          imageUrl != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    imageUrl,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        _MiniSexBox(symbol: sexSymbol, color: sexColor),
                  ),
                )
              : _MiniSexBox(symbol: sexSymbol, color: sexColor),
          const SizedBox(height: 8),
          Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            textAlign: TextAlign.center,
          ),
          if (morph.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                morph,
                style:
                    const TextStyle(color: Color(0xFF888888), fontSize: 10),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}

class _MiniSexBox extends StatelessWidget {
  final String symbol;
  final Color color;
  const _MiniSexBox({required this.symbol, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(
          symbol,
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
}

// ── Group Card ────────────────────────────────────────────────────────────────

class _GroupCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;
  final bool small;

  const _GroupCard({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    final iconSize = small ? 28.0 : 36.0;
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: 16, vertical: small ? 10 : 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: iconSize,
            height: iconSize,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(icon, color: color, size: small ? 14 : 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: small ? Colors.grey : Colors.white,
                fontSize: small ? 12 : 14,
              ),
            ),
          ),
          Text(
            '$count마리',
            style: TextStyle(
              color: color,
              fontSize: small ? 12 : 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 2),
          Icon(Icons.chevron_right,
              color: Colors.grey, size: small ? 14 : 18),
        ],
      ),
    );
  }
}

// ── Toggle Row ────────────────────────────────────────────────────────────────

class _ToggleRow extends StatelessWidget {
  final String label;
  final int count;
  final bool isExpanded;
  final VoidCallback onToggle;
  final bool subtle;

  const _ToggleRow({
    required this.label,
    required this.count,
    required this.isExpanded,
    required this.onToggle,
    this.subtle = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: 16, vertical: subtle ? 10 : 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF2A2A2A)),
        ),
        child: Row(
          children: [
            Icon(
              isExpanded
                  ? Icons.keyboard_arrow_up
                  : Icons.keyboard_arrow_down,
              color: Colors.grey,
              size: subtle ? 16 : 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: subtle
                      ? Colors.grey
                      : Colors.white.withValues(alpha: 0.75),
                  fontSize: subtle ? 12 : 14,
                ),
              ),
            ),
            Text(
              '$count마리',
              style: TextStyle(
                color: Colors.grey,
                fontSize: subtle ? 11 : 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Task Card ─────────────────────────────────────────────────────────────────

class _TaskCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final int? count;
  final String? subtitle;
  final VoidCallback? onTap;

  const _TaskCard({
    required this.icon,
    required this.label,
    required this.color,
    this.count,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 130,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            count != null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$count마리',
                        style: TextStyle(
                            color: color,
                            fontSize: 13,
                            fontWeight: FontWeight.bold),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: const TextStyle(
                              color: Color(0xFF888888), fontSize: 11),
                        ),
                    ],
                  )
                : const Text(
                    '준비 중',
                    style: TextStyle(color: Colors.grey, fontSize: 11),
                  ),
          ],
        ),
      ),
    );
  }
}

// ── Loading Placeholder ───────────────────────────────────────────────────────

class _LoadingPlaceholder extends StatelessWidget {
  final double height;
  const _LoadingPlaceholder({this.height = 160});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFF4CAF82)),
        ),
      );
}
