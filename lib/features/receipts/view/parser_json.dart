class ParserJson {
  static dynamic searchKey(
    dynamic json,
    String key, {
    dynamic defaultValue = 'No data available',
  }) {
    if (json is Map<String, dynamic>) {
      for (final entry in json.entries) {
        final k = entry.key;
        final v = entry.value;
        if (k == key) {
          return v;
        }
        if (v is Map<String, dynamic>) {
          final result = searchKey(v, key, defaultValue: defaultValue);
          if (result != defaultValue) {
            return result;
          }
        }
        if (v is List<dynamic>) {
          for (final item in v) {
            final result = searchKey(item, key, defaultValue: defaultValue);
            if (result != defaultValue) {
              return result;
            }
          }
        }
      }
    } else if (json is List<dynamic>) {
      for (final item in json) {
        final result = searchKey(item, key, defaultValue: defaultValue);
        if (result != defaultValue) {
          return result;
        }
      }
    }
    return defaultValue;
  }
}
