
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/services/caching_services/csv_data_cache.dart';

class DynamicLineChart extends StatefulWidget {
  final String filePath;
  final Map<String, dynamic> chartOptions;
  final List<Map<String, dynamic>>? preProcessedData;

  const DynamicLineChart({
    super.key,
    required this.filePath,
    required this.chartOptions,
    this.preProcessedData,
  });

  @override
  State<DynamicLineChart> createState() => _DynamicLineChartState();
}

class _DynamicLineChartState extends State<DynamicLineChart> {
  List<List<dynamic>>? _data;
  List<String>? _headers;
  String? _selectedXColumn;
  String? _selectedYColumn;
  bool _isLoading = true;

  // Cached computed chart data — recomputed only when columns or data change
  List<FlSpot> _cachedSpots = [];
  double _cachedMinX = 0;
  double _cachedMaxX = 0;
  double _cachedMinY = 0;
  double _cachedMaxY = 0;

  /// Maximum points to render before downsampling kicks in.
  static const int _downsampleThreshold = 500;

  @override
  void initState() {
    super.initState();
    if (widget.preProcessedData != null) {
      _processPreProcessedData();
    } else {
      _loadCsvData();
    }
  }

  @override
  void didUpdateWidget(covariant DynamicLineChart oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If dataset changed, reload
    if (oldWidget.filePath != widget.filePath) {
      _loadCsvData();
      return;
    }

    // If column selections changed in options, recompute spots
    final oldX = oldWidget.chartOptions['selectedXColumn'];
    final oldY = oldWidget.chartOptions['selectedYColumn'];
    final newX = widget.chartOptions['selectedXColumn'];
    final newY = widget.chartOptions['selectedYColumn'];
    if (oldX != newX || oldY != newY) {
      _selectedXColumn = newX ?? _selectedXColumn;
      _selectedYColumn = newY ?? _selectedYColumn;
      _recomputeSpots();
    }

    // Visual-only option changes don't need recomputation — just rebuild the widget tree
  }

  void _processPreProcessedData() {
    final spots = widget.preProcessedData!
        .map(
          (row) => FlSpot(
            (row['x'] as num).toDouble(),
            (row['y'] as num).toDouble(),
          ),
        )
        .toList();

    setState(() {
      _isLoading = false;
      _headers = null;
      _data = null;
      _cachedSpots = spots;
      _computeBounds(_cachedSpots);
    });
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

      _recomputeSpots();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _data = null;
        _headers = null;
      });
    }
  }

  /// Recompute the FlSpot list from raw data. Called only when columns or data change.
  void _recomputeSpots() {
    if (_data == null ||
        _headers == null ||
        _selectedXColumn == null ||
        _selectedYColumn == null) {
      return;
    }

    final xIndex = _headers!.indexOf(_selectedXColumn!);
    final yIndex = _headers!.indexOf(_selectedYColumn!);

    if (xIndex < 0 || yIndex < 0) {
      setState(() => _cachedSpots = []);
      return;
    }

    List<FlSpot> spots = [];
    for (var row in _data!) {
      if (row.length <= xIndex || row.length <= yIndex) continue;
      final xRaw = row[xIndex];
      final yRaw = row[yIndex];

      double? x = _parseTimeValue(xRaw);
      double? y = _parseTimeValue(yRaw);

      if (x != null && y != null) {
        spots.add(FlSpot(x, y));
      }
    }
    spots.sort((a, b) => a.x.compareTo(b.x));

    // Downsample if needed
    if (spots.length > _downsampleThreshold) {
      spots = _lttbDownsample(spots, _downsampleThreshold);
    }

    if (!mounted) return;
    setState(() {
      _cachedSpots = spots;
      _computeBounds(_cachedSpots);
    });
  }

  /// Compute axis bounds from spots, with 10% padding.
  void _computeBounds(List<FlSpot> spots) {
    if (spots.isEmpty) {
      _cachedMinX = 0;
      _cachedMaxX = 0;
      _cachedMinY = 0;
      _cachedMaxY = 0;
      return;
    }

    double minX = spots.first.x, maxX = spots.first.x;
    double minY = spots.first.y, maxY = spots.first.y;

    for (final s in spots) {
      if (s.x < minX) minX = s.x;
      if (s.x > maxX) maxX = s.x;
      if (s.y < minY) minY = s.y;
      if (s.y > maxY) maxY = s.y;
    }

    final xPad = (maxX - minX) * 0.1;
    final yPad = (maxY - minY) * 0.1;

    _cachedMinX = minX - xPad;
    _cachedMaxX = maxX + xPad;
    _cachedMinY = minY - yPad;
    _cachedMaxY = maxY + yPad;
  }

  /// Largest-Triangle-Three-Buckets downsampling algorithm.
  /// Preserves the visual shape of the line while reducing point count.
  static List<FlSpot> _lttbDownsample(List<FlSpot> data, int targetCount) {
    if (data.length <= targetCount) return data;

    final sampled = <FlSpot>[data.first];
    final bucketSize = (data.length - 2) / (targetCount - 2);

    int a = 0; // index of previously selected point

    for (int i = 0; i < targetCount - 2; i++) {
      // Calculate the average point for the next bucket
      final avgRangeStart = ((i + 1) * bucketSize).floor() + 1;
      final avgRangeEnd = ((i + 2) * bucketSize).floor() + 1;
      final avgRangeEndClamped = avgRangeEnd < data.length ? avgRangeEnd : data.length;

      double avgX = 0, avgY = 0;
      int count = avgRangeEndClamped - avgRangeStart;
      if (count <= 0) count = 1;

      for (int j = avgRangeStart; j < avgRangeEndClamped; j++) {
        avgX += data[j].x;
        avgY += data[j].y;
      }
      avgX /= count;
      avgY /= count;

      // Point in current bucket with largest triangle area
      final rangeStart = (i * bucketSize).floor() + 1;
      final rangeEnd = ((i + 1) * bucketSize).floor() + 1;
      final rangeEndClamped = rangeEnd < data.length ? rangeEnd : data.length;

      double maxArea = -1;
      int maxAreaIndex = rangeStart;

      for (int j = rangeStart; j < rangeEndClamped; j++) {
        final area = ((data[a].x - avgX) * (data[j].y - data[a].y) -
                    (data[a].x - data[j].x) * (avgY - data[a].y))
                .abs() *
            0.5;
        if (area > maxArea) {
          maxArea = area;
          maxAreaIndex = j;
        }
      }

      sampled.add(data[maxAreaIndex]);
      a = maxAreaIndex;
    }

    sampled.add(data.last);
    return sampled;
  }

  double? _parseTimeValue(dynamic value) {
    if (value is num) {
      return value.toDouble();
    } else if (value is String) {
      try {
        DateTime? date;
        try {
          date = DateTime.parse(value);
        } catch (_) {
          date = DateFormat('yyyy-MM-dd HH:mm:ss').parse(value);
        }
        return date.millisecondsSinceEpoch.toDouble();
      } catch (e) {
        return double.tryParse(value);
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (widget.preProcessedData != null) {
      return _buildLineChart();
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
        const SizedBox(height: 16),
        Expanded(child: _buildLineChart()),
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
              _recomputeSpots();
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
              _recomputeSpots();
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

  Widget _buildLineChart() {
    if (_cachedSpots.isEmpty) {
      return const Center(child: Text('No valid data to display in chart'));
    }

    // Read visual options (these don't require recomputation)
    final lineColor = widget.chartOptions['lineColor'] ?? Colors.blue;
    final lineWidth = (widget.chartOptions['lineWidth'] ?? 3.0).toDouble();
    final isCurved = widget.chartOptions['isCurved'] ?? true;
    final showDots = widget.chartOptions['showDots'] ?? true;
    final dotColor = widget.chartOptions['dotColor'] ?? Colors.blue;
    final dotSize = (widget.chartOptions['dotSize'] ?? 5.0).toDouble();
    final showGrid = widget.chartOptions['gridLines'] ?? true;
    final showTooltip = widget.chartOptions['showTooltip'] ?? true;
    final backgroundColor =
        widget.chartOptions['backgroundColor'] ?? Colors.transparent;

    // Axis bounds — use auto-scale with cached bounds, or manual overrides
    final autoScale = widget.chartOptions['autoScale'] ?? true;
    final effectiveMinX = _cachedMinX;
    final effectiveMaxX = _cachedMaxX;
    final minY = autoScale ? _cachedMinY : (widget.chartOptions['minY'] ?? _cachedMinY);
    final maxY = autoScale ? _cachedMaxY : (widget.chartOptions['maxY'] ?? _cachedMaxY);

    return LayoutBuilder(
      builder: (context, constraints) {
        return ClipRect(
          child: Container(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            color: backgroundColor,
            child: LineChart(
              LineChartData(
                minX: effectiveMinX,
                maxX: effectiveMaxX,
                minY: minY,
                maxY: maxY,
                gridData: FlGridData(show: showGrid),
                titlesData: _buildTitlesData(),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: Colors.grey.shade300, width: 1),
                ),
                clipData: FlClipData.all(),
                lineBarsData: [
                  LineChartBarData(
                    spots: _cachedSpots,
                    isCurved: isCurved,
                    color: lineColor,
                    barWidth: lineWidth,
                    isStrokeCapRound: true,
                    preventCurveOverShooting: true,
                    dotData: FlDotData(
                      show: showDots,
                      getDotPainter: (spot, percent, bar, index) =>
                          FlDotCirclePainter(
                        radius: dotSize,
                        color: dotColor,
                        strokeWidth: 0,
                      ),
                    ),
                    belowBarData: BarAreaData(show: false),
                  ),
                ],
                lineTouchData: LineTouchData(
                  enabled: showTooltip,
                  touchTooltipData: LineTouchTooltipData(
                    tooltipRoundedRadius: 8,
                    tooltipMargin: 16,
                    tooltipPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    tooltipHorizontalOffset: 0,
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final xValue = _isDateColumn(_selectedXColumn)
                            ? DateFormat('yyyy-MM-dd HH:mm').format(
                                DateTime.fromMillisecondsSinceEpoch(
                                  spot.x.toInt(),
                                ),
                              )
                            : spot.x.toStringAsFixed(2);

                        final yValue = _isDateColumn(_selectedYColumn)
                            ? DateFormat('yyyy-MM-dd HH:mm').format(
                                DateTime.fromMillisecondsSinceEpoch(
                                  spot.y.toInt(),
                                ),
                              )
                            : spot.y.toStringAsFixed(2);

                        return LineTooltipItem(
                          '($xValue,\n$yValue)',
                          const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      }).toList();
                    },
                  ),
                  handleBuiltInTouches: true,
                  getTouchedSpotIndicator: (barData, spotIndexes) {
                    return spotIndexes.map((spotIndex) {
                      return TouchedSpotIndicatorData(
                        FlLine(
                          color: Colors.blue.withValues(alpha: 0.8),
                          strokeWidth: 2,
                          dashArray: [5, 5],
                        ),
                        FlDotData(
                          getDotPainter: (spot, percent, barData, index) {
                            return FlDotCirclePainter(
                              radius: 8,
                              color: Colors.white,
                              strokeWidth: 3,
                              strokeColor: barData.color ?? Colors.blue,
                            );
                          },
                        ),
                      );
                    }).toList();
                  },
                ),
                extraLinesData: ExtraLinesData(
                  horizontalLines: [],
                  verticalLines: [],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  FlTitlesData _buildTitlesData() {
    return FlTitlesData(
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 60,
          getTitlesWidget: (value, meta) {
            if (_isDateColumn(_selectedXColumn)) {
              final date = DateTime.fromMillisecondsSinceEpoch(value.toInt());
              return SideTitleWidget(
                meta: meta,
                child: RotatedBox(
                  quarterTurns: 1,
                  child: Text(
                    DateFormat('HH:mm').format(date),
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
              );
            }
            return SideTitleWidget(
              meta: meta,
              child: Text(
                value.toStringAsFixed(1),
                style: const TextStyle(fontSize: 10),
              ),
            );
          },
        ),
      ),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 60,
          getTitlesWidget: (value, meta) {
            if (_isDateColumn(_selectedYColumn)) {
              final date = DateTime.fromMillisecondsSinceEpoch(value.toInt());
              return SideTitleWidget(
                meta: meta,
                child: Text(
                  DateFormat('HH:mm').format(date),
                  style: const TextStyle(fontSize: 10),
                ),
              );
            }
            return SideTitleWidget(
              meta: meta,
              child: Text(
                value.toStringAsFixed(1),
                style: const TextStyle(fontSize: 10),
              ),
            );
          },
        ),
      ),
      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
    );
  }

  /// Check if a column contains date/time values by sampling first 3 rows.
  bool _isDateColumn(String? columnName) {
    if (columnName == null || _data == null || _data!.isEmpty) return false;

    final columnIndex = _headers!.indexOf(columnName);
    if (columnIndex < 0) return false;

    int checkedValues = 0;
    final sampleSize = _data!.length < 3 ? _data!.length : 3;
    for (int i = 0; i < sampleSize; i++) {
      final row = _data![i];
      if (row.length > columnIndex && row[columnIndex] != null) {
        if (row[columnIndex] is String) {
          try {
            DateTime.parse(row[columnIndex].toString());
            checkedValues++;
          } catch (_) {
            return false;
          }
        } else {
          return false;
        }
      }
    }
    return checkedValues > 0;
  }
}
