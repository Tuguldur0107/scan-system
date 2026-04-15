import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/local/local_scan.dart';

class ScanDataTable extends StatefulWidget {
  const ScanDataTable({
    super.key,
    required this.scans,
    required this.totalCount,
    required this.onOpenDetails,
  });

  final List<LocalScan> scans;
  final int totalCount;
  final ValueChanged<LocalScan> onOpenDetails;

  @override
  State<ScanDataTable> createState() => _ScanDataTableState();
}

class _ScanDataTableState extends State<ScanDataTable> {
  static const _headers = <String>[
    '#',
    'Илгээсэн ID',
    'Баркод',
    'Огноо',
    'Цаг',
    'Даалгавар',
    'Хэрэглэгч',
    'Төлөв',
  ];

  _CellRef? _anchor;
  _CellRef? _focus;
  _CellRef? _hovered;
  final FocusNode _focusNode = FocusNode();

  bool get _hasSelection => _anchor != null && _focus != null;

  bool get _hasRangeSelection =>
      _hasSelection &&
      (_anchor!.row != _focus!.row || _anchor!.column != _focus!.column);

  bool get _isAwaitingRangeEnd =>
      _hasSelection &&
      _anchor!.row == _focus!.row &&
      _anchor!.column == _focus!.column;

  @override
  void didUpdateWidget(covariant ScanDataTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scans != widget.scans) {
      _clearSelection();
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _clearSelection() {
    if (!_hasSelection) return;
    setState(() {
      _anchor = null;
      _focus = null;
      _hovered = null;
    });
  }

  void _handleCellTap(int row, int column) {
    _focusNode.requestFocus();
    final tapped = _CellRef(row, column);
    setState(() {
      if (_anchor == null || (_hasRangeSelection && _focus != null)) {
        _anchor = tapped;
        _focus = tapped;
        _hovered = null;
        return;
      }

      _focus = tapped;
      _hovered = null;
    });
  }

  void _handleHover(int row, int column) {
    if (!_isAwaitingRangeEnd) return;
    final hovered = _CellRef(row, column);
    if (_hovered?.row == hovered.row && _hovered?.column == hovered.column) {
      return;
    }
    setState(() => _hovered = hovered);
  }

  void _selectRow(int row) {
    _focusNode.requestFocus();
    setState(() {
      _anchor = _CellRef(row, 0);
      _focus = _CellRef(row, _headers.length - 1);
      _hovered = null;
    });
  }

  void _selectColumn(int column) {
    _focusNode.requestFocus();
    setState(() {
      _anchor = _CellRef(0, column);
      _focus = _CellRef(widget.scans.length - 1, column);
      _hovered = null;
    });
  }

  bool _isSelected(int row, int column) {
    if (!_hasSelection) return false;

    final effectiveFocus = _hovered ?? _focus!;
    final minRow = math.min(_anchor!.row, effectiveFocus.row);
    final maxRow = math.max(_anchor!.row, effectiveFocus.row);
    final minColumn = math.min(_anchor!.column, effectiveFocus.column);
    final maxColumn = math.max(_anchor!.column, effectiveFocus.column);

    return row >= minRow &&
        row <= maxRow &&
        column >= minColumn &&
        column <= maxColumn;
  }

  Future<void> _copyFiltered(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: _buildTsv(widget.scans)));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${widget.scans.length} мөр clipboard руу хуулагдлаа'),
      ),
    );
  }

  Future<void> _copySelection(BuildContext context) async {
    if (!_hasSelection) return;

    final effectiveFocus = _hovered ?? _focus!;
    final minRow = math.min(_anchor!.row, effectiveFocus.row);
    final maxRow = math.max(_anchor!.row, effectiveFocus.row);
    final minColumn = math.min(_anchor!.column, effectiveFocus.column);
    final maxColumn = math.max(_anchor!.column, effectiveFocus.column);

    final lines = <String>[];
    lines.add(_headers.sublist(minColumn, maxColumn + 1).join('\t'));
    for (var row = minRow; row <= maxRow; row++) {
      final cells = _rowValues(widget.scans[row], row);
      lines.add(cells.sublist(minColumn, maxColumn + 1).join('\t'));
    }

    await Clipboard.setData(ClipboardData(text: lines.join('\n')));
    if (!context.mounted) return;

    final rowCount = maxRow - minRow + 1;
    final colCount = maxColumn - minColumn + 1;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$rowCount x $colCount selection хуулагдлаа')),
    );
  }

  String _buildTsv(List<LocalScan> scans) {
    final lines = <String>[_headers.join('\t')];
    for (var i = 0; i < scans.length; i++) {
      lines.add(_rowValues(scans[i], i).join('\t'));
    }
    return lines.join('\n');
  }

  List<String> _rowValues(LocalScan scan, int index) {
    final dt = scan.scannedAt;
    final date = '${dt.year}-${_two(dt.month)}-${_two(dt.day)}';
    final time = '${_two(dt.hour)}:${_two(dt.minute)}:${_two(dt.second)}';
    return [
      '${index + 1}',
      scan.sendId ?? '-',
      scan.barcodeValue,
      date,
      time,
      scan.notes ?? '-',
      scan.username ?? '-',
      scan.synced ? 'Синк хийсэн' : 'Хүлээгдэж буй',
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        const SingleActivator(LogicalKeyboardKey.keyC, control: true):
            const _CopySelectionIntent(),
        const SingleActivator(LogicalKeyboardKey.keyC, meta: true):
            const _CopySelectionIntent(),
        const SingleActivator(LogicalKeyboardKey.escape):
            const _ClearSelectionIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _CopySelectionIntent: CallbackAction<_CopySelectionIntent>(
            onInvoke: (_) {
              if (_hasSelection) {
                _copySelection(context);
              }
              return null;
            },
          ),
          _ClearSelectionIntent: CallbackAction<_ClearSelectionIntent>(
            onInvoke: (_) {
              _clearSelection();
              return null;
            },
          ),
        },
        child: Focus(
          focusNode: _focusNode,
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withAlpha(240),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Filtered records',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${widget.totalCount} нийт мөрөөс ${widget.scans.length} мөр харагдаж байна.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.outline,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      Chip(
                        avatar: const Icon(Icons.table_rows, size: 16),
                        label: Text('${widget.scans.length} мөр'),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _hasSelection
                              ? 'Range сонгогдсон. Ctrl/Cmd+C дарж copy хийж болно.'
                              : 'Cell дарж эхлүүлээд hover хийгээд дахин дарж range select хийнэ.',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: () => _copyFiltered(context),
                        icon: const Icon(Icons.copy_all),
                        label: const Text('Filtered copy'),
                      ),
                      if (_hasSelection) ...[
                        const SizedBox(width: 8),
                        FilledButton.tonalIcon(
                          onPressed: () => _copySelection(context),
                          icon: const Icon(Icons.content_copy),
                          label: const Text('Selection copy'),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Selection clear',
                          onPressed: _clearSelection,
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ],
                  ),
                ),
                const Divider(height: 1),
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth < 760) {
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: _buildMobileList(context),
                      );
                    }

                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: _buildDesktopTable(context),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileList(BuildContext context) {
    return Column(
      children: widget.scans
          .asMap()
          .entries
          .map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  margin: EdgeInsets.zero,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => widget.onOpenDetails(entry.value),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  entry.value.barcodeValue,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              _statusChip(entry.value.synced),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _metaChip(
                                '#${entry.key + 1}',
                                Icons.format_list_numbered,
                              ),
                              _metaChip(
                                entry.value.sendId ?? '-',
                                Icons.tag,
                              ),
                              _metaChip(
                                _formatDateTime(entry.value.scannedAt),
                                Icons.schedule,
                              ),
                              _metaChip(
                                entry.value.username ?? '-',
                                Icons.person_outline,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Task: ${entry.value.notes ?? '-'}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildDesktopTable(BuildContext context) {
    final borderColor = Theme.of(context).colorScheme.outlineVariant;
    final headerColor = Theme.of(context).colorScheme.surfaceContainerHighest;

    return Table(
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      columnWidths: const {
        0: FixedColumnWidth(56),
        1: FixedColumnWidth(220),
        2: FixedColumnWidth(190),
        3: FixedColumnWidth(112),
        4: FixedColumnWidth(98),
        5: FixedColumnWidth(180),
        6: FixedColumnWidth(150),
        7: FixedColumnWidth(132),
        8: FixedColumnWidth(72),
      },
      border: TableBorder.all(color: borderColor),
      children: [
        TableRow(
          decoration: BoxDecoration(color: headerColor),
          children: [
            for (var i = 0; i < _headers.length; i++)
              _headerCell(context, _headers[i], column: i),
            _headerCell(context, ''),
          ],
        ),
        for (var row = 0; row < widget.scans.length; row++)
          _buildDataRow(context, row),
      ],
    );
  }

  TableRow _buildDataRow(BuildContext context, int row) {
    final scan = widget.scans[row];
    final values = _rowValues(scan, row);

    return TableRow(
      children: [
        for (var column = 0; column < values.length; column++)
          _dataCell(
            context,
            text: values[column],
            row: row,
            column: column,
            monospace: column == 1 || column == 2,
            status: column == 7 ? scan.synced : null,
          ),
        _actionCell(context, scan),
      ],
    );
  }

  Widget _headerCell(BuildContext context, String text, {int? column}) {
    return InkWell(
      onTap: column == null || widget.scans.isEmpty
          ? null
          : () => _selectColumn(column),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
      ),
    );
  }

  Widget _dataCell(
    BuildContext context, {
    required String text,
    required int row,
    required int column,
    bool monospace = false,
    bool? status,
  }) {
    final selected = _isSelected(row, column);
    final selectionColor = Theme.of(context).colorScheme.primary.withAlpha(24);

    return MouseRegion(
      onEnter: (_) => _handleHover(row, column),
      child: InkWell(
        onTap: () =>
            column == 0 ? _selectRow(row) : _handleCellTap(row, column),
        onDoubleTap: () => widget.onOpenDetails(widget.scans[row]),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          color: selected ? selectionColor : null,
          alignment: Alignment.centerLeft,
          child: status == null
              ? Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFamily: monospace ? 'monospace' : null,
                        fontWeight: monospace ? FontWeight.w700 : null,
                      ),
                )
              : _statusChip(status),
        ),
      ),
    );
  }

  Widget _actionCell(BuildContext context, LocalScan scan) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      child: IconButton(
        visualDensity: VisualDensity.compact,
        tooltip: 'Detail',
        onPressed: () => widget.onOpenDetails(scan),
        icon: const Icon(Icons.open_in_new, size: 18),
      ),
    );
  }

  Widget _statusChip(bool synced) {
    final color = synced ? const Color(0xFF0F8B68) : const Color(0xFFB84C4C);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        synced ? 'Синк хийсэн' : 'Хүлээгдэж буй',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _metaChip(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 6),
          Text(text),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$month/$day $hour:$minute';
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
}

class _CellRef {
  const _CellRef(this.row, this.column);

  final int row;
  final int column;
}

class _CopySelectionIntent extends Intent {
  const _CopySelectionIntent();
}

class _ClearSelectionIntent extends Intent {
  const _ClearSelectionIntent();
}
