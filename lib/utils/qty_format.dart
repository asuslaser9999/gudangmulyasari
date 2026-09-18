String formatQty(num value) {
  if (value % 1 == 0) return value.toInt().toString();
  var text = value.toStringAsFixed(4);
  text = text.replaceFirst(RegExp(r'0+$'), '');
  text = text.replaceFirst(RegExp(r'\.$'), '');
  return text;
}

double? parseQty(String raw) {
  final trimmed = raw.trim().replaceAll(',', '.');
  if (trimmed.isEmpty) return null;
  return double.tryParse(trimmed);
}

DateTime parseIsoDate(dynamic value) {
  if (value is DateTime) return value;
  final text = value?.toString() ?? '';
  return DateTime.tryParse(text) ?? DateTime.now();
}

String dateToIso(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
