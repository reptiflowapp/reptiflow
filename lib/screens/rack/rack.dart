class Rack {
  final String id;
  final String name;
  final int rows;
  final int cols;

  const Rack({
    required this.id,
    required this.name,
    required this.rows,
    required this.cols,
  });

  factory Rack.fromJson(Map<String, dynamic> j) => Rack(
        id: j['id'] as String,
        name: j['name'] as String,
        rows: j['rows'] as int,
        cols: j['cols'] as int,
      );
}

class RackSlot {
  final String id;
  final String rackId;
  final int rowIndex;
  final int colIndex;
  final String? reptileId;
  final String? reptieName;
  final String? reptileMorph;
  final String? reptieSex;

  const RackSlot({
    required this.id,
    required this.rackId,
    required this.rowIndex,
    required this.colIndex,
    this.reptileId,
    this.reptieName,
    this.reptileMorph,
    this.reptieSex,
  });

  factory RackSlot.fromJson(Map<String, dynamic> j) {
    final r = j['reptiles'] as Map<String, dynamic>?;
    return RackSlot(
      id: j['id'] as String,
      rackId: j['rack_id'] as String,
      rowIndex: j['row_index'] as int,
      colIndex: j['col_index'] as int,
      reptileId: j['reptile_id'] as String?,
      reptieName: r?['name'] as String?,
      reptileMorph: r?['morph'] as String?,
      reptieSex: r?['sex'] as String?,
    );
  }
}

class RackPosition {
  final String rackName;
  final int rowIndex;
  final int colIndex;
  final int totalFloors;

  const RackPosition({
    required this.rackName,
    required this.rowIndex,
    required this.colIndex,
    required this.totalFloors,
  });

  // 1층이 맨 아래 → 층 번호 = totalFloors - rowIndex
  String get label => '$rackName ${colIndex + 1}열 ${totalFloors - rowIndex}층';
}
