import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/feeding.dart';

const _green = Color(0xFF4CAF82);
const _surface = Color(0xFF1E1E1E);
const _card = Color(0xFF2A2A2A);

class RecipeScreen extends StatefulWidget {
  const RecipeScreen({super.key});

  @override
  State<RecipeScreen> createState() => _RecipeScreenState();
}

class _RecipeScreenState extends State<RecipeScreen> {
  List<FeedingRecipe> _recipes = [];
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
      final data = await Supabase.instance.client
          .from('feeding_recipes')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _recipes = (data as List)
              .map((e) => FeedingRecipe.fromJson(e as Map<String, dynamic>))
              .toList();
        });
      }
    } catch (e) {
      _snack('불러오기 실패: $e', error: true);
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

  Future<void> _openDialog({FeedingRecipe? editing}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _RecipeDialog(editing: editing),
    );
    if (result == true) _load();
  }

  Future<void> _delete(FeedingRecipe recipe) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        title: const Text('레시피 삭제', style: TextStyle(color: Colors.white)),
        content: Text(
          '\'${recipe.name}\'을(를) 삭제하시겠습니까?',
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
      await Supabase.instance.client
          .from('feeding_recipes')
          .delete()
          .eq('id', recipe.id);
      _snack('레시피가 삭제되었습니다');
      _load();
    } catch (e) {
      _snack('삭제 실패: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: _surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('레시피 관리', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: _green),
            tooltip: '레시피 추가',
            onPressed: () => _openDialog(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _green))
          : _recipes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.restaurant_menu_outlined,
                          size: 64, color: Colors.grey.shade700),
                      const SizedBox(height: 16),
                      Text('등록된 레시피가 없습니다',
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 16)),
                      const SizedBox(height: 8),
                      Text('+ 버튼으로 레시피를 추가해보세요',
                          style: TextStyle(
                              color: Colors.grey.shade700, fontSize: 13)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  color: _green,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                    itemCount: _recipes.length,
                    itemBuilder: (_, i) {
                      final r = _recipes[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: _surface,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          leading: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: _green.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.restaurant_outlined,
                                color: _green, size: 20),
                          ),
                          title: Text(
                            r.name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600),
                          ),
                          subtitle: r.components.isEmpty
                              ? null
                              : Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    r.componentSummary,
                                    style: const TextStyle(
                                        color: Color(0xFF888888),
                                        fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined,
                                    color: Colors.grey, size: 20),
                                onPressed: () => _openDialog(editing: r),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: Colors.redAccent, size: 20),
                                onPressed: () => _delete(r),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

// ── 레시피 추가/수정 다이얼로그 ────────────────────────────────────────────────

class _RecipeDialog extends StatefulWidget {
  final FeedingRecipe? editing;
  const _RecipeDialog({this.editing});

  @override
  State<_RecipeDialog> createState() => _RecipeDialogState();
}

class _RecipeDialogState extends State<_RecipeDialog> {
  final _nameCtrl = TextEditingController();
  final List<_ComponentRow> _rows = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.editing != null) {
      _nameCtrl.text = widget.editing!.name;
      for (final e in widget.editing!.components.entries) {
        _rows.add(_ComponentRow(
          nameCtrl: TextEditingController(text: e.key),
          pctCtrl: TextEditingController(text: e.value.toString()),
        ));
      }
    }
    if (_rows.isEmpty) _addRow();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    for (final r in _rows) {
      r.nameCtrl.dispose();
      r.pctCtrl.dispose();
    }
    super.dispose();
  }

  void _addRow() {
    setState(() => _rows.add(_ComponentRow(
          nameCtrl: TextEditingController(),
          pctCtrl: TextEditingController(),
        )));
  }

  void _removeRow(int i) {
    final row = _rows.removeAt(i);
    row.nameCtrl.dispose();
    row.pctCtrl.dispose();
    setState(() {});
  }

  int get _totalPct => _rows.fold(
      0, (sum, r) => sum + (int.tryParse(r.pctCtrl.text.trim()) ?? 0));

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _snack('레시피 이름을 입력해주세요');
      return;
    }
    final components = <String, int>{};
    for (final r in _rows) {
      final k = r.nameCtrl.text.trim();
      final v = int.tryParse(r.pctCtrl.text.trim()) ?? 0;
      if (k.isNotEmpty && v > 0) components[k] = v;
    }
    if (_totalPct > 100) {
      _snack('비율 합계가 100%를 초과합니다');
      return;
    }

    setState(() => _saving = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final payload = {
        'user_id': userId,
        'name': name,
        'components': components,
      };
      if (widget.editing != null) {
        await Supabase.instance.client
            .from('feeding_recipes')
            .update(payload)
            .eq('id', widget.editing!.id);
      } else {
        await Supabase.instance.client
            .from('feeding_recipes')
            .insert(payload);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _snack('저장 실패: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.redAccent));
  }

  @override
  Widget build(BuildContext context) {
    final total = _totalPct;
    final overLimit = total > 100;

    return AlertDialog(
      backgroundColor: _card,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: Text(
        widget.editing != null ? '레시피 수정' : '레시피 추가',
        style: const TextStyle(color: Colors.white),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameCtrl,
                style: const TextStyle(color: Colors.white),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: '레시피 이름',
                  labelStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: const Color(0xFF1E1E1E),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _green),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('성분 구성',
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 8),
              ...List.generate(_rows.length, (i) {
                final row = _rows[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: TextField(
                          controller: row.nameCtrl,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14),
                          onChanged: (_) => setState(() {}),
                          decoration: _miniDeco('성분명 (예: 레파시)'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 70,
                        child: TextField(
                          controller: row.pctCtrl,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14),
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                          decoration: _miniDeco('%'),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline,
                            color: Colors.redAccent, size: 20),
                        onPressed: _rows.length > 1 ? () => _removeRow(i) : null,
                      ),
                    ],
                  ),
                );
              }),
              TextButton.icon(
                onPressed: _addRow,
                icon: const Icon(Icons.add, color: _green, size: 18),
                label: const Text('성분 추가',
                    style: TextStyle(color: _green, fontSize: 13)),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    '합계: $total%',
                    style: TextStyle(
                      color: overLimit ? Colors.redAccent : Colors.grey,
                      fontSize: 12,
                      fontWeight:
                          overLimit ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  if (overLimit) ...[
                    const SizedBox(width: 6),
                    const Text(
                      '100% 초과!',
                      style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('취소', style: TextStyle(color: Colors.grey)),
        ),
        TextButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child:
                      CircularProgressIndicator(strokeWidth: 2, color: _green),
                )
              : const Text('저장',
                  style: TextStyle(
                      color: _green, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

InputDecoration _miniDeco(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF555555), fontSize: 13),
      filled: true,
      fillColor: const Color(0xFF1E1E1E),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _green),
      ),
    );

class _ComponentRow {
  final TextEditingController nameCtrl;
  final TextEditingController pctCtrl;
  _ComponentRow({required this.nameCtrl, required this.pctCtrl});
}
