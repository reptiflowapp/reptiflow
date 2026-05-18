import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../reptiles/reptile.dart';
import 'rack.dart';

class RackDetailScreen extends StatefulWidget {
  final Rack rack;
  const RackDetailScreen({super.key, required this.rack});

  @override
  State<RackDetailScreen> createState() => _RackDetailScreenState();
}

class _RackDetailScreenState extends State<RackDetailScreen> {
  static const _green = Color(0xFF4CAF82);
  static const _cellSize = 52.0;
  static const _gap = 3.0;
  static const _rowLabelW = 30.0;
  static const _colLabelH = 26.0;

  List<RackSlot> _slots = [];
  List<Reptile> _reptiles = [];
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
            .from('rack_slots')
            .select('*, reptiles(id, name, morph, sex)')
            .eq('rack_id', widget.rack.id)
            .not('reptile_id', 'is', null),
        client.from('reptiles').select().order('name'),
      ]);

      if (mounted) {
        setState(() {
          _slots = (results[0] as List)
              .map((e) => RackSlot.fromJson(e as Map<String, dynamic>))
              .toList();
          _reptiles = (results[1] as List)
              .map((e) => Reptile.fromJson(e as Map<String, dynamic>))
              .toList();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('불러오기 실패: $e'),
              backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Map<String, RackSlot> get _slotMap =>
      {for (final s in _slots) '${s.rowIndex}-${s.colIndex}': s};

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _assign(int row, int col, String reptileId) async {
    try {
      final client = Supabase.instance.client;
      // Remove this reptile from any slot (same or different rack)
      await client.from('rack_slots').delete().eq('reptile_id', reptileId);
      // Place in the new slot
      await client.from('rack_slots').insert({
        'rack_id': widget.rack.id,
        'row_index': row,
        'col_index': col,
        'reptile_id': reptileId,
      });
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('배치 실패: $e'),
              backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _remove(String slotId) async {
    try {
      await Supabase.instance.client
          .from('rack_slots')
          .delete()
          .eq('id', slotId);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('제거 실패: $e'),
              backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _move(RackSlot source, int targetRow, int targetCol) async {
    if (source.rowIndex == targetRow && source.colIndex == targetCol) return;
    final target = _slotMap['$targetRow-$targetCol'];
    try {
      final client = Supabase.instance.client;
      await client.from('rack_slots').update({
        'row_index': targetRow,
        'col_index': targetCol,
      }).eq('id', source.id);
      // If target was occupied, move that reptile to source's old position (swap)
      if (target != null) {
        await client.from('rack_slots').update({
          'row_index': source.rowIndex,
          'col_index': source.colIndex,
        }).eq('id', target.id);
      }
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('이동 실패: $e'),
              backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  // ── Tap Handlers ──────────────────────────────────────────────────────────

  void _onEmptyTap(int row, int col) {
    final assignedIds =
        _slots.map((s) => s.reptileId).whereType<String>().toSet();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _ReptilePickerSheet(
        reptiles: _reptiles,
        assignedIds: assignedIds,
        onSelect: (id) {
          Navigator.pop(context);
          _assign(row, col, id);
        },
      ),
    );
  }

  void _onOccupiedTap(RackSlot slot) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _SlotInfoSheet(
        slot: slot,
        onRemove: () {
          Navigator.pop(context);
          _remove(slot.id);
        },
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.rack.name,
                style: const TextStyle(color: Colors.white, fontSize: 17)),
            Text(
              '${widget.rack.cols}열 × ${widget.rack.rows}층',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.grey),
            onPressed: _load,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _green))
          : _buildGrid(),
    );
  }

  Widget _buildGrid() {
    final slotMap = _slotMap;
    final occupied = _slots.length;
    final total = widget.rack.rows * widget.rack.cols;

    return Column(
      children: [
        // 점유 요약 바
        Container(
          color: const Color(0xFF1A1A1A),
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: _green,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 6),
              Text('배치됨 $occupied',
                  style:
                      const TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(width: 16),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: Colors.grey.shade700),
                ),
              ),
              const SizedBox(width: 6),
              Text('비어있음 ${total - occupied}',
                  style:
                      const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),
        // 격자
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 렉 이름 (층 레이블 영역 제외, 셀 영역 기준 가운데)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const SizedBox(width: _rowLabelW),
                        SizedBox(
                          width: widget.rack.cols * (_cellSize + _gap),
                          child: Text(
                            widget.rack.name,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 층 (위에서부터 최상층 → 1층)
                  ...List.generate(
                    widget.rack.rows,
                    (row) {
                      // row=0이 맨 위 = 최상층
                      final floorNum = widget.rack.rows - row;
                      return Row(
                      children: [
                        // 층 레이블
                        SizedBox(
                          width: _rowLabelW,
                          height: _cellSize + _gap,
                          child: Center(
                            child: Text('$floorNum',
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 11)),
                          ),
                        ),
                        // 슬롯 셀
                        ...List.generate(widget.rack.cols, (col) {
                          final slot = slotMap['$row-$col'];
                          return _SlotCell(
                            slot: slot,
                            onTap: slot == null
                                ? () => _onEmptyTap(row, col)
                                : () => _onOccupiedTap(slot),
                            onDrop: (src) => _move(src, row, col),
                          );
                        }),
                      ],
                    );
                    },
                  ),
                  // 열 헤더 (1열, 2열, ...) — 그리드 아래
                  Row(
                    children: [
                      // 좌하단 코너: "층" 레이블
                      SizedBox(
                        width: _rowLabelW,
                        height: _colLabelH,
                        child: const Center(
                          child: Text('층',
                              style: TextStyle(
                                  color: Colors.grey, fontSize: 10)),
                        ),
                      ),
                      ...List.generate(
                        widget.rack.cols,
                        (col) => SizedBox(
                          width: _cellSize + _gap,
                          height: _colLabelH,
                          child: Center(
                            child: Text('${col + 1}열',
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 11)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Slot Cell ─────────────────────────────────────────────────────────────────

class _SlotCell extends StatelessWidget {
  static const _green = Color(0xFF4CAF82);
  static const _size = 52.0;
  static const _gap = 3.0;

  final RackSlot? slot;
  final VoidCallback onTap;
  final void Function(RackSlot) onDrop;

  const _SlotCell(
      {required this.slot, required this.onTap, required this.onDrop});

  @override
  Widget build(BuildContext context) {
    return DragTarget<RackSlot>(
      onWillAcceptWithDetails: (d) => d.data.id != slot?.id,
      onAcceptWithDetails: (d) => onDrop(d.data),
      builder: (_, candidates, _) {
        final isOver = candidates.isNotEmpty;
        return Padding(
          padding: const EdgeInsets.only(right: _gap, bottom: _gap),
          child: SizedBox(
            width: _size,
            height: _size,
            child: slot != null
                ? Draggable<RackSlot>(
                    data: slot,
                    feedback: Material(
                      color: Colors.transparent,
                      child: _buildOccupied(isOver: false, dragging: false,
                          asFeedback: true),
                    ),
                    childWhenDragging: _buildEmpty(isOver: false),
                    child: GestureDetector(
                      onTap: onTap,
                      child: _buildOccupied(isOver: isOver, dragging: false,
                          asFeedback: false),
                    ),
                  )
                : GestureDetector(
                    onTap: onTap,
                    child: _buildEmpty(isOver: isOver),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildEmpty({required bool isOver}) {
    return Container(
      decoration: BoxDecoration(
        color: isOver
            ? _green.withValues(alpha: 0.2)
            : const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(8),
        border: isOver
            ? Border.all(color: _green.withValues(alpha: 0.8), width: 1.5)
            : Border.all(color: Colors.transparent),
      ),
    );
  }

  Widget _buildOccupied(
      {required bool isOver,
      required bool dragging,
      required bool asFeedback}) {
    return Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        color: isOver
            ? _green.withValues(alpha: 0.35)
            : _green.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isOver
              ? Colors.white.withValues(alpha: 0.5)
              : _green.withValues(alpha: 0.55),
        ),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(4),
      child: Text(
        slot!.reptieName ?? '',
        style: TextStyle(
          color: asFeedback ? Colors.white : Colors.white.withValues(alpha: 0.9),
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
        textAlign: TextAlign.center,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

// ── Reptile Picker Sheet ──────────────────────────────────────────────────────

class _ReptilePickerSheet extends StatefulWidget {
  final List<Reptile> reptiles;
  final Set<String> assignedIds;
  final void Function(String id) onSelect;

  const _ReptilePickerSheet({
    required this.reptiles,
    required this.assignedIds,
    required this.onSelect,
  });

  @override
  State<_ReptilePickerSheet> createState() => _ReptilePickerSheetState();
}

class _ReptilePickerSheetState extends State<_ReptilePickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.reptiles
        .where((r) =>
            r.name.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.35,
      builder: (_, scrollCtrl) => Column(
        children: [
          // 핸들
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade600,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('개체 선택',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ),
          ),
          // 검색
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: '이름 검색',
                hintStyle: const TextStyle(color: Colors.grey),
                prefixIcon:
                    const Icon(Icons.search, color: Colors.grey, size: 20),
                filled: true,
                fillColor: const Color(0xFF2A2A2A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          // 목록
          Expanded(
            child: ListView.builder(
              controller: scrollCtrl,
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final r = filtered[i];
                final alreadyHere = widget.assignedIds.contains(r.id);
                final sexSymbol = r.sex == 'male'
                    ? '♂'
                    : r.sex == 'female'
                        ? '♀'
                        : '?';
                final sexColor = r.sex == 'male'
                    ? const Color(0xFF42A5F5)
                    : r.sex == 'female'
                        ? const Color(0xFFF48FB1)
                        : Colors.grey;
                return ListTile(
                  onTap: () => widget.onSelect(r.id),
                  leading: CircleAvatar(
                    backgroundColor:
                        sexColor.withValues(alpha: 0.15),
                    child: Text(sexSymbol,
                        style:
                            TextStyle(fontSize: 18, color: sexColor)),
                  ),
                  title: Text(r.name,
                      style: const TextStyle(color: Colors.white)),
                  subtitle: Text(
                    [
                      if (r.morph?.isNotEmpty == true) r.morph!,
                      if (r.species?.isNotEmpty == true) r.species!,
                    ].join(' · '),
                    style: const TextStyle(
                        color: Colors.grey, fontSize: 12),
                  ),
                  trailing: alreadyHere
                      ? const Text('이 렉에 배치됨',
                          style: TextStyle(
                              color: Color(0xFFFF9800), fontSize: 11))
                      : const Icon(Icons.chevron_right,
                          color: Colors.grey, size: 18),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Slot Info Sheet ───────────────────────────────────────────────────────────

class _SlotInfoSheet extends StatelessWidget {
  final RackSlot slot;
  final VoidCallback onRemove;

  const _SlotInfoSheet({required this.slot, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final sexSymbol = slot.reptieSex == 'male'
        ? '♂'
        : slot.reptieSex == 'female'
            ? '♀'
            : '?';
    final sexColor = slot.reptieSex == 'male'
        ? const Color(0xFF42A5F5)
        : slot.reptieSex == 'female'
            ? const Color(0xFFF48FB1)
            : Colors.grey;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 핸들
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade600,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // 개체 정보
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: sexColor.withValues(alpha: 0.15),
                child: Text(sexSymbol,
                    style:
                        TextStyle(fontSize: 22, color: sexColor)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      slot.reptieName ?? '이름 없음',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w600),
                    ),
                    if (slot.reptileMorph?.isNotEmpty == true)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(slot.reptileMorph!,
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 13)),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Color(0xFF333333)),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: const [
                Icon(Icons.drag_indicator,
                    color: Colors.grey, size: 16),
                SizedBox(width: 6),
                Text('그리드에서 드래그로 다른 칸으로 이동할 수 있습니다',
                    style:
                        TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onRemove,
              icon: const Icon(Icons.remove_circle_outline, size: 18),
              label: const Text('이 칸에서 제거'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side: const BorderSide(color: Colors.redAccent),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
