import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/services/caching_services/csv_data_cache.dart';

class DynamicBarChart extends StatefulWidget {
  final String filePath;
  final Map<String, dynamic> chartOptions;
  final List<Map<String, dynamic>>? preProcessedData;

  const DynamicBarChart({
    super.key,
    required this.filePath,
    required this.chartOptions,
    this.preProcessedData,
  });

  @override
  State<DynamicBarChart> createState() => _DynamicBarChartState();
}

class _DynamicBarChartState extends State<DynamicBarChart> {
  List<List<dynamic>>? _data;
  List<String>? _headers;
  String? _selectedXColumn;
  String? _selectedYColumn;
  bool _isLoading = true;

  // Cached computed chart data — recomputed only when columns or data change
  List<BarChartGroupData> _cachedBarGroups = [];
  double _cachedMaxY = 0;
  bool _isDataTruncated = false;

  /// Maximum number of bars to render for performance.
  static const int _maxBars = 100;

  @override
  void initState() {
    super.initState();
    _loadCsvData();
  }

  @override
  void didUpdateWidget(covariant DynamicBarChart oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If dataset changed, reload
    if (oldWidget.filePath != widget.filePath) {
      _loadCsvData();
      return;
    }

    // If column selections changed in options, recompute bar groups
    final oldX = oldWidget.chartOptions['selectedXColumn'];
    final oldY = oldWidget.chartOptions['selectedYColumn'];
    final newX = widget.chartOptions['selectedXColumn'];
    final newY = widget.chartOptions['selectedYColumn'];
    if (oldX != newX || oldY != newY) {
      _selectedXColumn = newX ?? _selectedXColumn;
      _selectedYColumn = newY ?? _selectedYColumn;
      _recomputeBarGroups();
      return;
    }

    // Visual-only option changes — rebuild bar groups since colors/widths are baked in
    _recomputeBarGroups();
  }

  Future<void> _loadCsvData() async {
    try {
      final csvData = await CsvDataCache().getCsvData(widget.filePath);

      if (!mounted) return;

      setState(() {
        _headers = csvData.headers;
        _data = csvData.rows;
        _selectedXColumn = widget.chartOptions['selectedXColumn'] ?? _headers!.first;
        _selectedYColumn = widget.chartOptions['selectedYColumn'] ??
            CsvDataCache.findNumericColumn(_headers!, _data!);
        _isLoading = false;
      });

      _recomputeBarGroups();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _data = null;
        _headers = null;
      });
    }
  }

  /// Recompute the BarChartGroupData list from raw data.
  /// Called only when columns, data, or visual options change.
  void _recomputeBarGroups() {
    if (_data == null ||
        _headers == null ||
        _selectedXColumn == null ||
        _selectedYColumn == null) {
      return;
    }

    final xIndex = _headers!.indexOf(_selectedXColumn!);
    final yIndex = _headers!.indexOf(_selectedYColumn!);

    if (xIndex < 0 || yIndex < 0) {
      setState(() {
        _cachedBarGroups = [];
        _isDataTruncated = false;
      });
      return;
    }

    final barGroups = <BarChartGroupData>[];
    int barCount = 0;
    bool truncated = false;

    for (int i = 0; i < _data!.length; i++) {
      final row = _data![i];
      if (row.length <= xIndex || row.length <= yIndex) continue;
      final yRaw = row[yIndex];

      double? y = yRaw is num ? yRaw.toDouble() : double.tryParse(yRaw.toString());
      if (y != null) {
        if (barCount >= _maxBars) {
          truncated = true;
          break;
        }
        barGroups.add(
          BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: y,
                color: widget.chartOptions['barColor'] ?? Colors.blue,
                width: (widget.chartOptions['barWidth'] ?? 16.0).toDouble(),
                borderRadius: BorderRadius.circular(
                    (widget.chartOptions['borderRadius'] ?? 4.0).toDouble()),
                borderSide: (widget.chartOptions['showBorder'] ?? false)
                    ? BorderSide(
                        color: widget.chartOptions['borderColor'] ?? Colors.black,
                        width: (widget.chartOptions['borderWidth'] ?? 1.0).toDouble(),
                      )
                    : BorderSide.none,
                backDrawRodData: BackgroundBarChartRodData(show: false),
              ),
            ],
          ),
        );
        barCount++;
      }
    }

    // Compute max Y for axis bounds
    double maxY = 0;
    for (final g in barGroups) {
      final y = g.barRods.first.toY;
      if (y > maxY) maxY = y;
    }

    if (!mounted) return;
    setState(() {
      _cachedBarGroups = barGroups;
      _cachedMaxY = maxY * 1.1;
      _isDataTruncated = truncated;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (widget.preProcessedData != null) {
      return _buildBarChart();
    }

    if (_data == null ||
        _headers == null ||
        _data!.isEmpty ||
        _headers!.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            const Text('Failed to load CSV data'),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _loadCsvData,
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildColumnSelectors(),
        if (_isDataTruncated)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 14, color: Colors.orange.shade700),
                const SizedBox(width: 4),
                Text(
                  'Showing first $_maxBars bars of ${_data!.length} data points',
                  style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        Expanded(child: _buildBarChart()),
      ],
    );
  }

  Widget _buildColumnSelectors() {
    final xColumn = _selectedXColumn ?? _headers!.first;
    final yColumn = _selectedYColumn ?? _headers!.first;

    return Row(
      children: [
        Expanded(
          child: _buildDropdown(
            'X Axis:',
            xColumn,
            _headers!,
            (value) {
              setState(() {
                _selectedXColumn = value;
                widget.chartOptions['selectedXColumn'] = value;
              });
              _recomputeBarGroups();
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildDropdown(
            'Y Axis:',
            yColumn,
            _headers!,
            (value) {
              setState(() {
                _selectedYColumn = value;
                widget.chartOptions['selectedYColumn'] = value;
              });
              _recomputeBarGroups();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown(
    String label,
    String value,
    List<String> items,
    Function(String) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13)),
        DropdownButton(
          items: items
              .map(
                (item) => DropdownMenuItem(value: item, child: Text(item)),
              )
              .toList(),
          value: value,
          isExpanded: true,
          onChanged: (newValue) {
            if (newValue != null) {
              onChanged(newValue);
            }
          },
        ),
      ],
    );
  }

  Widget _buildBarChart() {
    if (_cachedBarGroups.isEmpty) {
      return const Center(child: Text('No valid data to display in chart'));
    }

    final minY = (widget.chartOptions['minY'] ?? 0.0).toDouble();
    final maxY = (widget.chartOptions['maxY'] ?? _cachedMaxY).toDouble();

    return LayoutBuilder(
      builder: (context, constraints) {
        return ClipRect(
          child: Container(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            color: widget.chartOptions['backgroundColor'] ?? Colors.transparent,
            child: BarChart(
              BarChartData(
                barGroups: _cachedBarGroups,
                groupsSpace: (widget.chartOptions['groupsSpace'] ?? 16.0).toDouble(),
                alignment: BarChartAlignment.values[
                    (widget.chartOptions['alignment'] ?? 0).clamp(0, 2)],
                gridData: FlGridData(show: widget.chartOptions['showGrid'] ?? true),
                borderData: FlBorderData(
                  show: widget.chartOptions['showBorderData'] ?? false,
                  border: Border.all(color: Colors.grey.shade300, width: 1),
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (_data != null &&
                            value.toInt() >= 0 &&
                            value.toInt() < _data!.length) {
                          final xIndex = _headers!.indexOf(_selectedXColumn!);
                          final xVal = _data![value.toInt()][xIndex];
                          return SideTitleWidget(
                            meta: meta,
                            child: Text(xVal.toString(),
                                style: const TextStyle(fontSize: 10)),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return SideTitleWidget(
                          meta: meta,
                          child: Text(value.toStringAsFixed(1),
                              style: const TextStyle(fontSize: 10)),
                        );
                      },
                    ),
                  ),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                minY: minY,
                maxY: maxY,
                barTouchData: BarTouchData(
                  enabled: widget.chartOptions['enableTouch'] ?? true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final xIndex = _headers!.indexOf(_selectedXColumn!);
                      final xVal = _data![group.x.toInt()][xIndex];
                      return BarTooltipItem(
                        '$xVal\n${rod.toY}',
                        const TextStyle(color: Colors.white),
                      );
                    },
                  ),
                  allowTouchBarBackDraw:
                      widget.chartOptions['allowBackgroundBarTouch'] ?? true,
                ),
                baselineY: (widget.chartOptions['baselineY'] ?? 0.0).toDouble(),
              ),
            ),
          ),
        );
      },
    );
  }
}