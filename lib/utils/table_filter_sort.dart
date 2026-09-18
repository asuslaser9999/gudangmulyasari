class SortOption<T> {
  const SortOption({required this.value, required this.label});

  final T value;
  final String label;
}

bool matchesSearch(String query, Iterable<String> fields) {
  final normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) return true;
  return fields.any((field) => field.toLowerCase().contains(normalized));
}
