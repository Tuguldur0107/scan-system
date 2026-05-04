import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart' show Data, DoubleCellValue, Excel,
    FormulaCellValue, IntCellValue, BoolCellValue, TextCellValue;

/// Reads an Excel cell as a clean string suitable for barcode / qty / text
/// parsing. Excel stores most "numbers" as doubles, so a barcode like
/// `8888888000003` ends up as `DoubleCellValue(8888888000003.0)`. The
/// default `.toString()` returns `"8888888000003.0"`, which the digit
/// stripping in `EpcConverter.normalizeToGtin14` would turn into a
/// different 14-digit value with a wrong check digit, breaking the EPC
/// encode. This wrapper special-cases each cell type so integer-valued
/// doubles come back without the trailing `.0`, and `NaN`/`Infinity` /
/// formula errors collapse to an empty string instead of throwing.
String safeCellText(Data? cell) {
  try {
    final v = cell?.value;
    if (v == null) return '';

    if (v is IntCellValue) {
      return v.value.toString();
    }
    if (v is DoubleCellValue) {
      final d = v.value;
      if (d.isNaN || d.isInfinite) return '';
      if (d == d.truncateToDouble()) {
        // Use BigInt to keep precision past 2^53.
        return BigInt.from(d).toString();
      }
      return d.toString();
    }
    if (v is TextCellValue) {
      return v.value.toString();
    }
    if (v is BoolCellValue) {
      return v.value ? '1' : '0';
    }
    if (v is FormulaCellValue) {
      return '';
    }

    final s = v.toString();
    if (s == 'NaN' || s == 'Infinity' || s == '-Infinity') return '';
    return s;
  } catch (_) {
    return '';
  }
}

/// Strips Excel-export artefacts from a numeric string so digit-only
/// post-processing doesn't accidentally turn `"8888888000003.0"` into
/// `"88888880000030"`. Handles a trailing `.0`/`.00…` and basic scientific
/// notation (`"1.23e+12"`) which can appear in CSVs exported from Excel.
String cleanNumericText(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return s;

  final trailing = RegExp(r'^([+-]?\d+)\.0+$').firstMatch(s);
  if (trailing != null) return trailing.group(1)!;

  final sci = RegExp(r'^([+-]?)(\d+)(?:\.(\d+))?[eE]([+-]?\d+)$').firstMatch(s);
  if (sci != null) {
    try {
      final sign = sci.group(1) ?? '';
      final intPart = sci.group(2)!;
      final fracPart = sci.group(3) ?? '';
      final exp = int.parse(sci.group(4)!);
      final combined = '$intPart$fracPart';
      final shift = exp - fracPart.length;
      if (shift >= 0) {
        return '$sign$combined${'0' * shift}';
      }
      if (-shift >= combined.length) return '${sign}0';
      return '$sign${combined.substring(0, combined.length + shift)}';
    } catch (_) {
      return s;
    }
  }
  return s;
}

/// Parses a quantity-like string into a positive int, capped at 100000 so
/// a typo can't cause millions of EPC rows to be generated. Accepts CSV
/// values written as `"5.0"` (Excel default for ints).
int parseQty(String raw, {int defaultQty = 1}) {
  final s = raw.trim();
  if (s.isEmpty) return defaultQty;
  var n = int.tryParse(s);
  if (n == null) {
    final d = double.tryParse(s);
    if (d != null && d.isFinite) {
      n = d.toInt();
    }
  }
  if (n == null || n <= 0) return defaultQty;
  if (n > 100000) return 100000;
  return n;
}

/// Result of [decodeWorkbook]. `sheetName` is null when the workbook only
/// contains one sheet; otherwise the caller should prompt the user to pick
/// which sheet to import.
class WorkbookDecode {
  WorkbookDecode({required this.excel, required this.sheetNames});

  final Excel excel;
  final List<String> sheetNames;
}

/// Decodes an `.xlsx` workbook and returns the sheet names so the caller
/// can show a sheet picker if there are multiple sheets. Throws a string
/// message on a corrupt workbook so the import UI can surface it directly.
WorkbookDecode decodeWorkbook(Uint8List bytes) {
  final Excel excel;
  try {
    excel = Excel.decodeBytes(bytes);
  } catch (e) {
    throw 'Excel decode амжилтгүй: $e';
  }
  if (excel.tables.isEmpty) {
    throw 'Excel файлд sheet олдсонгүй.';
  }
  return WorkbookDecode(excel: excel, sheetNames: excel.tables.keys.toList());
}

/// Parses a CSV/TXT byte buffer into rows of cells. UTF-8 with malformed
/// bytes accepted so a Mongolian-Excel-exported CSV doesn't break the
/// import on a stray byte. Accepts `,`, `;` and tab as separators.
List<List<String>> parseCsvBytes(Uint8List bytes) {
  final text = utf8.decode(bytes, allowMalformed: true);
  final lines = text
      .split(RegExp(r'[\r\n]+'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
  return [
    for (final line in lines)
      line.split(RegExp(r'[,;\t]')).map((e) => e.trim()).toList(),
  ];
}

/// Tries to find a column in `rows[0]` whose header text contains any of
/// [hints]. Returns null if no header matches (the caller can then prompt
/// the user). Hints are matched case-insensitively as substrings.
int? detectColumnByHints(
  List<List<Data?>> rows,
  int maxColumns,
  Set<String> hints,
) {
  if (rows.isEmpty) return null;
  final first = rows.first;
  for (var c = 0; c < maxColumns; c++) {
    final h = c < first.length ? safeCellText(first[c]).toLowerCase() : '';
    if (h.isEmpty) continue;
    for (final hint in hints) {
      if (h.contains(hint)) return c;
    }
  }
  return null;
}

/// Same as [detectColumnByHints] but for CSV-style header rows already
/// split into strings.
int? detectCsvColumnByHints(
  List<List<String>> rows,
  Set<String> hints,
) {
  if (rows.isEmpty) return null;
  final first = rows.first;
  for (var c = 0; c < first.length; c++) {
    final h = first[c].toLowerCase();
    if (h.isEmpty) continue;
    for (final hint in hints) {
      if (h.contains(hint)) return c;
    }
  }
  return null;
}
