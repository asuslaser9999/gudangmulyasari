enum StaffAccessMode {
  fullAccess('full', 'Akses penuh'),
  timeRestricted('time_restricted', 'Terbatas jam operasional'),
  blocked('blocked', 'Diblokir');

  const StaffAccessMode(this.storageKey, this.label);

  final String storageKey;
  final String label;

  static StaffAccessMode fromStorageKey(String? key) {
    for (final mode in StaffAccessMode.values) {
      if (mode.storageKey == key) return mode;
    }
    return StaffAccessMode.timeRestricted;
  }
}
