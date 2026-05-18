import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'rack.dart';
import 'rack_detail_screen.dart';

class RackScreen extends StatefulWidget {
  const RackScreen({super.key});

  @override
  State<RackScreen> createState() => _RackScreenState();
}

class _RackScreenState extends State<RackScreen> {
  static const _green = Color(0xFF4CAF82);

  List<Rack> _racks = [];
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
          .from('racks')
          .select()
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _racks = (data as List)
              .map((e) => Rack.fromJson(e as Map<String, dynamic>))
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

  Future<void> _showAddDialog() async {
    final nameCtrl = TextEditingController();
    int rows = 9;
    int cols = 3;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF2A2A2A),
          title: const Text('렉 추가', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: '렉 이름',
                  labelStyle: TextStyle(color: Colors.grey),
                  enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey)),
                  focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: _green)),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const SizedBox(
                    width: 44,
                    child: Text('열 수', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  ),
                  _SpinBox(
                    value: cols,
                    min: 1,
                    max: 30,
                    onChanged: (v) => setDialogState(() => cols = v),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const SizedBox(
                    width: 44,
                    child: Text('층 수', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  ),
                  _SpinBox(
                    value: rows,
                    min: 1,
                    max: 20,
                    onChanged: (v) => setDialogState(() => rows = v),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                final name = nameCtrl.text.trim();
                final r = rows;
                final c = cols;
                Navigator.pop(ctx);
                await _addRack(name, r, c);
              },
              child:
                  const Text('추가', style: TextStyle(color: _green, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
    nameCtrl.dispose();
  }

  Future<void> _addRack(String name, int rows, int cols) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      await Supabase.instance.client.from('racks').insert({
        'user_id': userId,
        'name': name,
        'rows': rows,
        'cols': cols,
      });
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('추가 실패: $e'),
              backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _deleteRack(Rack rack) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text('렉 삭제', style: TextStyle(color: Colors.white)),
        content: Text(
          "'${rack.name}'을(를) 삭제하시겠습니까?\n배치된 개체 슬롯 정보도 모두 삭제됩니다.",
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
    if (confirmed != true) return;
    try {
      await Supabase.instance.client.from('racks').delete().eq('id', rack.id);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('삭제 실패: $e'),
              backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _green))
          : _racks.isEmpty
              ? _EmptyState()
              : RefreshIndicator(
                  onRefresh: _load,
                  color: _green,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    itemCount: _racks.length,
                    itemBuilder: (_, i) => _RackCard(
                      rack: _racks[i],
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                RackDetailScreen(rack: _racks[i]),
                          ),
                        );
                        _load();
                      },
                      onDelete: () => _deleteRack(_racks[i]),
                    ),
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _green,
        foregroundColor: Colors.white,
        tooltip: '렉 추가',
        onPressed: _showAddDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ── Rack Card ─────────────────────────────────────────────────────────────────

class _RackCard extends StatelessWidget {
  final Rack rack;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _RackCard(
      {required this.rack, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF82).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.grid_view_outlined,
                  color: Color(0xFF4CAF82), size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rack.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${rack.cols}열 × ${rack.rows}층  ·  총 ${rack.rows * rack.cols}칸',
                    style: const TextStyle(
                        color: Color(0xFF888888), fontSize: 13),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: Colors.redAccent, size: 20),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.grid_view_outlined,
              size: 64, color: Colors.grey.shade700),
          const SizedBox(height: 16),
          Text('등록된 렉이 없습니다',
              style:
                  TextStyle(color: Colors.grey.shade600, fontSize: 16)),
          const SizedBox(height: 8),
          Text('+ 버튼으로 첫 렉을 추가해보세요',
              style:
                  TextStyle(color: Colors.grey.shade700, fontSize: 13)),
        ],
      ),
    );
  }
}

// ── Spin Box ──────────────────────────────────────────────────────────────────

class _SpinBox extends StatelessWidget {
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const _SpinBox(
      {required this.value,
      required this.min,
      required this.max,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SpinBtn(
          icon: Icons.remove,
          enabled: value > min,
          onTap: () => onChanged(value - 1),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text('$value',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
        ),
        _SpinBtn(
          icon: Icons.add,
          enabled: value < max,
          onTap: () => onChanged(value + 1),
        ),
      ],
    );
  }
}

class _SpinBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _SpinBtn(
      {required this.icon,
      required this.enabled,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: const Color(0xFF3A3A3A),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon,
            size: 16,
            color: enabled ? Colors.white : Colors.grey.shade700),
      ),
    );
  }
}
