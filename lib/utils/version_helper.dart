class VersionHelper {
  static List<int> parse(String version) {
    final cleaned = version.trim().toLowerCase();
    final match = RegExp(r'v?\.?(\d+(?:\.\d+)*)').firstMatch(cleaned);
    final numbers = match?.group(1) ?? '0';
    return numbers.split('.').map((p) => int.tryParse(p) ?? 0).toList();
  }

  static bool isNewer(String remote, String current) {
    final r = parse(remote);
    final c = parse(current);
    for (int i = 0; i < 3; i++) {
      final rv = i < r.length ? r[i] : 0;
      final cv = i < c.length ? c[i] : 0;
      if (rv > cv) return true;
      if (rv < cv) return false;
    }
    return false;
  }
}
