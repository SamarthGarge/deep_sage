import 'package:flutter/material.dart';

import '../../../core/services/core_services/visualization_service.dart';

class BarChartMatplotlibOptionsOverlay extends StatefulWidget {
  final Map<String, dynamic>? initialOptions;
  final Function(Map<String, dynamic> options) onOptionsChanged;
  final String? datasetPath;

  const BarChartMatplotlibOptionsOverlay({
    super.key,
    this.initialOptions,
    required this.onOptionsChanged,
    this.datasetPath,
  });

  @override
  State<BarChartMatplotlibOptionsOverlay> createState() =>
      _BarChartMatplotlibOptionsOverlayState();
}

class _BarChartMatplotlibOptionsOverlayState
    extends State<BarChartMatplotlibOptionsOverlay> {
  late final TextEditingController _titleController;
  late final TextEditingController _xLabelController;
  late final TextEditingController _yLabelController;

  // Column selection
  String? _selectedXColumn;
  String? _selectedYColumn;
  List<String> _availableColumns = [];
  bool _isLoadingColumns = true;

  // Bar style
  String _barColor = '#1f77b4';
  double _barWidth = 0.7;
  String _edgeColor = 'none';
  double _edgeWidth = 0.5;
  double _barAlpha = 1.0;

  // Orientation
  String _orientation = 'vertical';

  // Aggregation
  String _aggregation = 'sum';
  int _maxBars = 50;

  // Values
  bool _showValues = false;

  // Grid
  bool _showGrid = true;
  double _gridAlpha = 0.3;

  // Legend
  bool _showLegend = false;
  String _legendPosition = 'best';

  // Output
  String _outputFormat = 'PNG';
  int _outputDpi = 100;
  bool _transparentBackground = false;

  // Figure size
  double _figWidth = 10;
  double _figHeight = 6;

  final Map<String, bool> _expandedSections = {
    'columns': true,
    'barStyle': false,
    'layout': false,
    'grid': false,
    'legend': false,
    'output': false,
  };

  final List<String> _legendPositions = [
    'best', 'upper right', 'upper left', 'lower left',
    'lower right', 'right', 'center left', 'center right',
    'lower center', 'upper center', 'center',
  ];
  final List<String> _colorOptions = [
    '#1f77b4', '#ff7f0e', '#2ca02c', '#d62728', '#9467bd',
    '#8c564b', '#e377c2', '#7f7f7f', '#bcbd22', '#17becf',
    '#000000', '#e74c3c', '#3498db', '#2ecc71', '#f39c12',
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: 'Bar Chart');
    _xLabelController = TextEditingController(text: '');
    _yLabelController = TextEditingController(text: '');

    if (widget.initialOptions != null) {
      _applyInitialOptions(widget.initialOptions!);
    }

    _loadColumns();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _xLabelController.dispose();
    _yLabelController.dispose();
    super.dispose();
  }

  void _applyInitialOptions(Map<String, dynamic> opts) {
    _titleController.text = opts['title'] ?? 'Bar Chart';
    _xLabelController.text = opts['xLabel'] ?? '';
    _yLabelController.text = opts['yLabel'] ?? '';
    _selectedXColumn = opts['xColumn'];
    _selectedYColumn = opts['yColumn'];
    _barColor = opts['barColor'] ?? '#1f77b4';
    _barWidth = (opts['barWidth'] ?? 0.7).toDouble();
    _edgeColor = opts['edgeColor'] ?? 'none';
    _edgeWidth = (opts['edgeWidth'] ?? 0.5).toDouble();
    _barAlpha = (opts['barAlpha'] ?? 1.0).toDouble();
    _orientation = opts['orientation'] ?? 'vertical';
    _aggregation = opts['aggregation'] ?? 'sum';
    _maxBars = opts['maxBars'] ?? 50;
    _showValues = opts['showValues'] ?? false;
    _showGrid = opts['showGrid'] ?? true;
    _gridAlpha = (opts['gridAlpha'] ?? 0.3).toDouble();
    _showLegend = opts['showLegend'] ?? false;
    _legendPosition = opts['legendPosition'] ?? 'best';
    _outputFormat = opts['outputFormat'] ?? 'PNG';
    _outputDpi = opts['outputDpi'] ?? 100;
    _transparentBackground = opts['transparentBackground'] ?? false;
    _figWidth = (opts['figWidth'] ?? 10).toDouble();
    _figHeight = (opts['figHeight'] ?? 6).toDouble();
  }

  Future<void> _loadColumns() async {
    if (widget.datasetPath == null || widget.datasetPath!.isEmpty) {
      setState(() => _isLoadingColumns = false);
      return;
    }

    try {
      final visualizationService = VisualizationService();
      final columnSamples = await visualizationService.getDatasetColumns(
        widget.datasetPath!,
      );
      setState(() {
        _availableColumns = columnSamples.keys.toList();
        if (_selectedXColumn == null && _availableColumns.isNotEmpty) {
          _selectedXColumn = _availableColumns.first;
        }
        if (_selectedYColumn == null && _availableColumns.length > 1) {
          _selectedYColumn = _availableColumns[1];
        } else if (_selectedYColumn == null && _availableColumns.isNotEmpty) {
          _selectedYColumn = _availableColumns.first;
        }
        _isLoadingColumns = false;
      });
    } catch (e) {
      setState(() => _isLoadingColumns = false);
      debugPrint('Error loading columns: $e');
    }
  }

  Map<String, dynamic> _buildOptions() {
    return {
      'xColumn': _selectedXColumn,
      'yColumn': _selectedYColumn,
      'title': _titleController.text,
      'xLabel': _xLabelController.text.isNotEmpty ? _xLabelController.text : _selectedXColumn,
      'yLabel': _yLabelController.text.isNotEmpty ? _yLabelController.text : _selectedYColumn,
      'barColor': _barColor,
      'barWidth': _barWidth,
      'edgeColor': _edgeColor,
      'edgeWidth': _edgeWidth,
      'barAlpha': _barAlpha,
      'orientation': _orientation,
      'aggregation': _aggregation,
      'maxBars': _maxBars,
      'showValues': _showValues,
      'showGrid': _showGrid,
      'gridAlpha': _gridAlpha,
      'showLegend': _showLegend,
      'legendPosition': _legendPosition,
      'outputFormat': _outputFormat,
      'outputDpi': _outputDpi,
      'transparentBackground': _transparentBackground,
      'figWidth': _figWidth,
      'figHeight': _figHeight,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final textColor = isLight ? Colors.black : Colors.white;

    return Container(
      color: theme.scaffoldBackgroundColor,
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Matplotlib Bar Chart Options',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: textColor),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const Divider(),
          Expanded(
            child: _isLoadingColumns
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    children: [
                      _buildSection('columns', 'Column Selection', Icons.table_chart, [
                        _buildColumnDropdown('X Column', _selectedXColumn, (v) {
                          setState(() => _selectedXColumn = v);
                        }),
                        _buildColumnDropdown('Y Column', _selectedYColumn, (v) {
                          setState(() => _selectedYColumn = v);
                        }),
                        _buildTextField('Title', _titleController),
                        _buildTextField('X Label', _xLabelController),
                        _buildTextField('Y Label', _yLabelController),
                      ]),
                      _buildSection('barStyle', 'Bar Style', Icons.bar_chart, [
                        _buildColorSelector('Bar Color', _barColor, (v) {
                          setState(() => _barColor = v);
                        }),
                        _buildSlider('Bar Width', _barWidth, 0.1, 1.0, (v) {
                          setState(() => _barWidth = v);
                        }),
                        _buildSlider('Opacity', _barAlpha, 0.1, 1.0, (v) {
                          setState(() => _barAlpha = v);
                        }),
                        _buildSwitch('Show Values on Bars', _showValues, (v) {
                          setState(() => _showValues = v);
                        }),
                      ]),
                      _buildSection('layout', 'Layout', Icons.swap_horiz, [
                        _buildDropdown('Orientation', _orientation, ['vertical', 'horizontal'], (v) {
                          setState(() => _orientation = v!);
                        }),
                        _buildDropdown('Aggregation', _aggregation, ['sum', 'mean', 'count'], (v) {
                          setState(() => _aggregation = v!);
                        }),
                        _buildSlider('Max Bars', _maxBars.toDouble(), 10, 100, (v) {
                          setState(() => _maxBars = v.toInt());
                        }),
                      ]),
                      _buildSection('grid', 'Grid', Icons.grid_on, [
                        _buildSwitch('Show Grid', _showGrid, (v) {
                          setState(() => _showGrid = v);
                        }),
                        if (_showGrid)
                          _buildSlider('Grid Opacity', _gridAlpha, 0.1, 1.0, (v) {
                            setState(() => _gridAlpha = v);
                          }),
                      ]),
                      _buildSection('legend', 'Legend', Icons.legend_toggle, [
                        _buildSwitch('Show Legend', _showLegend, (v) {
                          setState(() => _showLegend = v);
                        }),
                        if (_showLegend)
                          _buildDropdown('Position', _legendPosition, _legendPositions, (v) {
                            setState(() => _legendPosition = v!);
                          }),
                      ]),
                      _buildSection('output', 'Output', Icons.image, [
                        _buildDropdown('Format', _outputFormat, ['PNG', 'SVG', 'PDF', 'JPEG'], (v) {
                          setState(() => _outputFormat = v!);
                        }),
                        _buildSlider('DPI', _outputDpi.toDouble(), 72, 600, (v) {
                          setState(() => _outputDpi = v.toInt());
                        }),
                        _buildSwitch('Transparent BG', _transparentBackground, (v) {
                          setState(() => _transparentBackground = v);
                        }),
                        _buildSlider('Width', _figWidth, 4, 20, (v) {
                          setState(() => _figWidth = v);
                        }),
                        _buildSlider('Height', _figHeight, 3, 16, (v) {
                          setState(() => _figHeight = v);
                        }),
                      ]),
                    ],
                  ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _selectedXColumn != null && _selectedYColumn != null
                  ? () {
                      final options = _buildOptions();
                      widget.onOptionsChanged(options);
                      Navigator.of(context).pop(options);
                    }
                  : null,
              icon: const Icon(Icons.bar_chart),
              label: const Text('Generate Bar Chart'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String key, String title, IconData icon, List<Widget> children) {
    final theme = Theme.of(context);
    final isExpanded = _expandedSections[key] ?? false;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          ListTile(
            leading: Icon(icon, color: theme.colorScheme.primary),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            trailing: Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
            onTap: () {
              setState(() => _expandedSections[key] = !isExpanded);
            },
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(children: children),
            ),
        ],
      ),
    );
  }

  Widget _buildColumnDropdown(String label, String? value, Function(String?) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        value: value != null && _availableColumns.contains(value) ? value : null,
        items: _availableColumns
            .map((col) => DropdownMenuItem(value: col, child: Text(col)))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildSlider(String label, double value, double min, double max, Function(double) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: StatefulBuilder(
        builder: (context, setLocalState) {
          return Row(
            children: [
              SizedBox(width: 100, child: Text(label)),
              Expanded(
                child: Slider(
                  value: value.clamp(min, max),
                  min: min,
                  max: max,
                  divisions: ((max - min) * 10).toInt().clamp(1, 100),
                  label: value.toStringAsFixed(1),
                  onChanged: (v) {
                    setLocalState(() => value = v);
                  },
                  onChangeEnd: (v) {
                    onChanged(v);
                  },
                ),
              ),
              SizedBox(width: 40, child: Text(value.toStringAsFixed(1))),
            ],
          );
        }
      ),
    );
  }

  Widget _buildSwitch(String label, bool value, Function(bool) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _buildDropdown<T>(String label, T value, List<T> items, Function(T?) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: DropdownButtonFormField<T>(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        value: value,
        items: items
            .map((item) => DropdownMenuItem<T>(value: item, child: Text(item.toString())))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildColorSelector(String label, String selectedColor, Function(String) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _colorOptions.map((color) {
              final isSelected = color == selectedColor;
              return GestureDetector(
                onTap: () => onChanged(color),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Color(int.parse(color.replaceFirst('#', '0xFF'))),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.white : Colors.transparent,
                      width: 2,
                    ),
                    boxShadow: isSelected
                        ? [BoxShadow(color: Colors.blue.withValues(alpha: 0.5), blurRadius: 6)]
                        : null,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
