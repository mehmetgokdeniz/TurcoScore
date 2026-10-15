/// SofaScore tipleri tutarsız döndürür (int yerine string vb.): toleranslı okuma.
int? tryInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? double.tryParse(value)?.round();
  return null;
}

double? tryDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.replaceAll(',', '.'));
  return null;
}

String? tryString(dynamic value) {
  if (value == null) return null;
  if (value is String) return value.isEmpty ? null : value;
  return value.toString();
}

Map<String, dynamic>? tryMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

List<Map<String, dynamic>> tryMapList(dynamic value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (tryMap(item) != null) tryMap(item)!,
  ];
}
