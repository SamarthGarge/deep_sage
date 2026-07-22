import 'dart:io';

import 'package:csv/csv.dart';

/// Parsed CSV data container.
class CsvData {
  final List<String> headers;
  final List<List<dynamic>> rows;

  const CsvData({required this.headers, required this.rows});
}

/// Singleton cache for parsed CSV data.
///
/// Avoids redundant disk I/O and CSV re-parsing when multiple chart widgets
/// reference the same dataset file. Entries are invalidated automatically
/// when the file's last-modified timestamp changes.
class CsvDataCache {
  static final CsvDataCache _instance = CsvDataCache._internal();
  factory CsvDataCache() => _instance;
  CsvDataCache._internal();

  static const int _maxEntries = 5;

  // Key: file path → value: cached entry
  final Map<String, _CsvCacheEntry> _cache = {};

  /// Returns parsed CSV data for [filePath], using cache when possible.
  ///
  /// Cache is invalidated when the file's last-modified time changes.
  Future<CsvData> getCsvData(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('CSV file does not exist: $filePath');
    }

    final lastModified = await file.lastModified();
    final existing = _cache[filePath];

    // Return cached data if file hasn't changed
    if (existing != null && existing.lastModified == lastModified) {
      // Move to end (most recently used)
      _cache.remove(filePath);
      _cache[filePath] = existing;
      return existing.data;
    }

    // Parse fresh
    final content = await file.readAsString();
    final csvTable = const CsvToListConverter(
      fieldDelimiter: ',',
      eol: '\n',
      shouldParseNumbers: true,
    ).convert(content);

    if (csvTable.isEmpty) {
      throw Exception('CSV file has no data');
    }

    final headers = csvTable[0].map((e) => e.toString()).toList();
    final rows = csvTable.length > 1 ? csvTable.sublist(1) : <List<dynamic>>[];

    final data = CsvData(headers: headers, rows: rows);

    // Evict oldest entry if at capacity
    if (_cache.length >= _maxEntries) {
      _cache.remove(_cache.keys.first);
    }

    _cache[filePath] = _CsvCacheEntry(
      data: data,
      lastModified: lastModified,
    );

    return data;
  }

  /// Find the first column whose data contains numeric values.
  static String? findNumericColumn(List<String> headers, List<List<dynamic>> rows) {
    if (headers.isEmpty || rows.isEmpty) return null;

    for (int i = 0; i < headers.length; i++) {
      // Only check first 5 rows for efficiency
      final sampleSize = rows.length < 5 ? rows.length : 5;
      for (int j = 0; j < sampleSize; j++) {
        if (rows[j].length > i) {
          final value = rows[j][i];
          if (value is num ||
              (value != null && double.tryParse(value.toString()) != null)) {
            return headers[i];
          }
        }
      }
    }
    return headers.first;
  }

  /// Clear all cached data.
  void clear() {
    _cache.clear();
  }
}

class _CsvCacheEntry {
  final CsvData data;
  final DateTime lastModified;

  const _CsvCacheEntry({required this.data, required this.lastModified});
}
