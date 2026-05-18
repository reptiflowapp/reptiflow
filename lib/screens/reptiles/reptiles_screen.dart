import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../rack/rack.dart';
import 'add_reptile_screen.dart';
import 'edit_reptile_screen.dart';
import 'reptile.dart';

// ── Screen ───────────────────────────────────────────────────────────────────

class ReptilesScreen extends StatefulWidget {
  const ReptilesScreen({super.key});

  @override
  State<ReptilesScreen> createState() => _ReptilesScreenState();
}

class _ReptilesScreenState extends State<ReptilesScreen> {
  static const _green = Color(0xFF4CAF82);

  List<Reptile> _reptiles = [];
  Map<String, RackPosition> _rackPositions = {};
  String _sexFilter = 'all'; // 'all' | 'male' | 'female'
  bool _isLoading = true;

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
            .select()
            .order('created_at', ascending: false),
        client
            .from('rack_slots')
            .select('reptile_id, row_index, col_index, racks(name, rows)')
            .not('reptile_id', 'is', null),
      ]);

      if (mounted) {
        final positions = <String, RackPosition>{};
        for (final raw in results[1] as List) {
          final s = raw as Map<String, dynamic>;
          final reptileId = s['reptile_id'] as String?;
          if (reptileId == null) continue;
          final rackData = s['racks'] as Map<String, dynamic>?;
          final rackName = rackData?['name'] as String? ?? '';
          final totalFloors = rackData?['rows'] as int? ?? 1;
          positions[reptileId] = RackPosition(
            rackName: rackName,
            rowIndex: s['row_index'] as int,
            colIndex: s['col_index'] as int,
            totalFloors: totalFloors,
          );
        }
        setState(() {
          _reptiles = (results[0] as List)
              .map((e) => Reptile.fromJson(e as Map<String, dynamic>))
              .toList();
          _rackPositions = positions;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('불러오기 실패: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Reptile> get _filtered {
    if (_sexFilter == 'all') return _reptiles;
    return _reptiles.where((r) => r.sex == _sexFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Column(
        children: [
          _FilterBar(
            selected: _sexFilter,
            count: filtered.length,
            onChanged: (v) => setState(() => _sexFilter = v),
          ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: _green),
                  )
                : filtered.isEmpty
                    ? _EmptyState(hasFilter: _sexFilter != 'all')
                    : RefreshIndicator(
                        onRefresh: _load,
                        color: _green,
                        child: ListView.builder(
                          padding:
                              const EdgeInsets.fromLTRB(16, 8, 16, 100),
                          itemCount: filtered.length,
                          itemBuilder: (_, i) => _ReptileCard(
                            reptile: filtered[i],
                            rackLabel: _rackPositions[filtered[i].id]?.label,
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => EditReptileScreen(
                                      reptile: filtered[i]),
                                ),
                              );
                              _load();
                            },
                          ),
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _green,
        foregroundColor: Colors.white,
        tooltip: '개체 추가',
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddReptileScreen()),
          );
          _load();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ── Filter Bar ───────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  final String selected;
  final int count;
  final ValueChanged<String> onChanged;

  const _FilterBar({
    required this.selected,
    required this.count,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1A1A1A),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          _FilterBtn(
            label: '전체',
            value: 'all',
            selected: selected,
            activeColor: const Color(0xFF4CAF82),
            onTap: onChanged,
          ),
          const SizedBox(width: 8),
          _FilterBtn(
            label: '♂ 수컷',
            value: 'male',
            selected: selected,
            activeColor: const Color(0xFF42A5F5),
            onTap: onChanged,
          ),
          const SizedBox(width: 8),
          _FilterBtn(
            label: '♀ 암컷',
            value: 'female',
            selected: selected,
            activeColor: const Color(0xFFF48FB1),
            onTap: onChanged,
          ),
          const Spacer(),
          Text(
            '$count마리',
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _FilterBtn extends StatelessWidget {
  final String label;
  final String value;
  final String selected;
  final Color activeColor;
  final ValueChanged<String> onTap;

  const _FilterBtn({
    required this.label,
    required this.value,
    required this.selected,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selected == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.15)
              : const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? activeColor : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? activeColor : Colors.grey,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

// ── Reptile Card ─────────────────────────────────────────────────────────────

class _ReptileCard extends StatelessWidget {
  final Reptile reptile;
  final String? rackLabel;
  final VoidCallback? onTap;
  const _ReptileCard({required this.reptile, this.rackLabel, this.onTap});

  static String _statusLabel(String s) => const {
        'active': '활성',
        'holdback': '홀드백',
        'available': '분양가능',
        'sold': '분양완료',
        'deceased': '무지개다리',
      }[s] ??
      s;

  static Color _statusColor(String s) => const {
        'active': Color(0xFF4CAF82),
        'holdback': Color(0xFFFF9800),
        'available': Color(0xFF42A5F5),
        'sold': Color(0xFF9E9E9E),
        'deceased': Color(0xFFEF5350),
      }[s] ??
      Color(0xFF9E9E9E);

  static (String symbol, Color color) _sexInfo(String sex) => switch (sex) {
        'male' => ('♂', Color(0xFF42A5F5)),
        'female' => ('♀', Color(0xFFF48FB1)),
        _ => ('?', Color(0xFF9E9E9E)),
      };

  @override
  Widget build(BuildContext context) {
    final (symbol, sexColor) = _sexInfo(reptile.sex);
    final statusColor = _statusColor(reptile.status);
    final subtitle = [
      if (reptile.morph?.isNotEmpty == true) reptile.morph!,
      if (reptile.species?.isNotEmpty == true) reptile.species!,
    ].join(' · ');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // 썸네일 (사진 있으면) or 성별 아이콘 원형
              if (reptile.imageUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    reptile.imageUrl!,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _SexIcon(
                        symbol: symbol, color: sexColor),
                  ),
                )
              else
                _SexIcon(symbol: symbol, color: sexColor),
              const SizedBox(width: 14),
              // 이름 + 모프/종 + 몸무게
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reptile.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(
                            color: Color(0xFF888888), fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (reptile.weightG != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        '${reptile.weightG!.toStringAsFixed(1)}g',
                        style: const TextStyle(
                            color: Color(0xFF666666), fontSize: 12),
                      ),
                    ],
                    if (rackLabel != null) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.grid_view_outlined,
                              size: 11, color: Color(0xFF4CAF82)),
                          const SizedBox(width: 3),
                          Text(
                            rackLabel!,
                            style: const TextStyle(
                                color: Color(0xFF4CAF82), fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              // 상태 배지
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: statusColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  _statusLabel(reptile.status),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool hasFilter;
  const _EmptyState({required this.hasFilter});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.pets_outlined,
              size: 64, color: Colors.grey.shade700),
          const SizedBox(height: 16),
          Text(
            hasFilter ? '해당하는 개체가 없습니다' : '등록된 개체가 없습니다',
            style:
                TextStyle(color: Colors.grey.shade600, fontSize: 16),
          ),
          if (!hasFilter) ...[
            const SizedBox(height: 8),
            Text(
              '+ 버튼으로 첫 개체를 추가해보세요',
              style:
                  TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}

class _SexIcon extends StatelessWidget {
  final String symbol;
  final Color color;
  const _SexIcon({required this.symbol, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          symbol,
          style: TextStyle(
            fontSize: 24,
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
}
