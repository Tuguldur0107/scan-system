class EpcConverterResult {
  const EpcConverterResult({
    required this.value,
    required this.message,
  });

  final String value;
  final String message;
}

class EpcConverter {
  // SGTIN-96 header.
  static const int _sgtin96Header = 0x30;

  // partition -> (companyPrefixBits, companyPrefixDigits, itemRefBits, itemRefDigits)
  static const List<(int, int, int, int)> _partitionTable = [
    (40, 12, 4, 1),
    (37, 11, 7, 2),
    (34, 10, 10, 3),
    (30, 9, 14, 4),
    (27, 8, 17, 5),
    (24, 7, 20, 6),
    (20, 6, 24, 7),
  ];

  static const int _defaultFilter = 1;
  static int _companyPrefixDigits = 7;

  static const Map<int, int> _digitsToPartition = {
    12: 0,
    11: 1,
    10: 2,
    9: 3,
    8: 4,
    7: 5,
    6: 6,
  };

  static int get companyPrefixDigits => _companyPrefixDigits;

  static void setCompanyPrefixDigits(int digits) {
    if (_digitsToPartition.containsKey(digits)) {
      _companyPrefixDigits = digits;
    }
  }

  static EpcConverterResult? tryConvertEitherDirection(String raw) {
    return tryConvertToBarcode(raw) ?? tryConvertToEpc(raw);
  }

  static EpcConverterResult? tryConvertToBarcode(String raw) {
    final cleaned = raw.trim().toUpperCase().replaceAll(RegExp(r'[^0-9A-F]'), '');
    if (cleaned.length != 24) return null;

    final value = BigInt.tryParse(cleaned, radix: 16);
    if (value == null) return null;

    final bits = value.toRadixString(2).padLeft(96, '0');
    final header = _bitsToInt(bits.substring(0, 8));
    if (header != _sgtin96Header) return null;

    final partition = _bitsToInt(bits.substring(11, 14));
    if (partition < 0 || partition >= _partitionTable.length) return null;

    final (cpBits, cpDigits, itemBits, itemDigits) = _partitionTable[partition];
    final cpStart = 14;
    final cpEnd = cpStart + cpBits;
    final itemEnd = cpEnd + itemBits;
    if (itemEnd > bits.length) return null;

    final companyPrefix =
        _bitsToInt(bits.substring(cpStart, cpEnd)).toString().padLeft(cpDigits, '0');
    final itemReference =
        _bitsToInt(bits.substring(cpEnd, itemEnd)).toString().padLeft(itemDigits, '0');

    final gtin13 = '$companyPrefix$itemReference';
    if (gtin13.length != 13) return null;

    final check = _computeGs1CheckDigit(gtin13);
    final barcode = '$gtin13$check';

    return EpcConverterResult(
      value: barcode,
      message: 'EPC хувиргав: $cleaned -> $barcode',
    );
  }

  static bool _isDigits(String digits, int len) =>
      digits.length == len && RegExp(r'^\d+$').hasMatch(digits);

  static bool isValidGtin12(String digits) {
    if (!_isDigits(digits, 12)) return false;
    final expected = _computeGs1CheckDigit(digits.substring(0, 11));
    return expected == int.tryParse(digits[11]);
  }

  static bool isValidGtin13(String digits) {
    if (!_isDigits(digits, 13)) return false;
    final expected = _computeGs1CheckDigit(digits.substring(0, 12));
    return expected == int.tryParse(digits[12]);
  }

  static bool isValidGtin14(String digits) {
    if (!_isDigits(digits, 14)) return false;
    final expected = _computeGs1CheckDigit(digits.substring(0, 13));
    return expected == int.tryParse(digits[13]);
  }

  /// Normalizes numeric input to a valid **GTIN-14** string (check digit on
  /// the first 13 digits), using GS1 padding rules:
  /// - Already valid GTIN-14: keep unchanged.
  /// - Valid GTIN-13 (EAN-13): prefix `0` and keep existing check.
  /// - Valid GTIN-12 (UPC-A): prefix `00` and keep existing check.
  /// - Shorter codes: left-pad with zeros to 14, then set the check digit.
  static String? normalizeToGtin14(String raw) {
    var digits = raw.trim().replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return null;
    if (digits.length > 14) return null;

    if (digits.length == 14 && isValidGtin14(digits)) {
      return digits;
    }
    if (digits.length == 13 && isValidGtin13(digits)) {
      return '0$digits';
    }
    if (digits.length == 12 && isValidGtin12(digits)) {
      return '00$digits';
    }

    while (digits.length < 14) {
      digits = '0$digits';
    }
    final core = digits.substring(0, 13);
    final check = _computeGs1CheckDigit(core);
    return '$core$check';
  }

  static EpcConverterResult? barcodeToSgtin96Epc(
    String raw, {
    int? serial,
  }) {
    final gtin14 = normalizeToGtin14(raw);
    if (gtin14 == null) return null;
    return encodeSgtin96FromGtin14(gtin14, serial: serial);
  }

  static EpcConverterResult? encodeSgtin96FromGtin14(
    String gtin14, {
    int? serial,
  }) {
    if (!isValidGtin14(gtin14)) return null;

    final core13 = gtin14.substring(0, 13);
    final partition = _digitsToPartition[_companyPrefixDigits] ?? 5;
    final (cpBits, cpDigits, itemBits, itemDigits) = _partitionTable[partition];

    final companyPrefix = core13.substring(0, cpDigits);
    final itemReference = core13.substring(cpDigits, cpDigits + itemDigits);

    final cpValue = int.parse(companyPrefix);
    final itemValue = int.parse(itemReference);
    // The SGTIN-96 serial field is 38 bits wide. We MUST do this clamp with
    // `BigInt`, because on dart2js the native `int << n` operator only
    // supports n <= 31 — `1 << 38` throws `Infinity or NaN toInt`, which
    // surfaces as a generic "Хөрвүүлэлтийн алдаа" in the UI on web.
    final serialBig = (serial == null || serial < 0)
        ? BigInt.parse(gtin14)
        : BigInt.from(serial);
    final serialNum = (serialBig % (BigInt.one << 38)).toInt();
    final serialBits =
        BigInt.from(serialNum).toRadixString(2).padLeft(38, '0');

    final bits =
        _toBits(_sgtin96Header, 8) +
        _toBits(_defaultFilter, 3) +
        _toBits(partition, 3) +
        _toBits(cpValue, cpBits) +
        _toBits(itemValue, itemBits) +
        serialBits;

    final epc =
        BigInt.parse(bits, radix: 2).toRadixString(16).toUpperCase().padLeft(24, '0');
    return EpcConverterResult(
      value: epc,
      message: 'Barcode хувиргав: $gtin14 -> $epc (CP:$cpDigits)',
    );
  }

  static EpcConverterResult? tryConvertToEpc(String raw) {
    final barcode = raw.trim().replaceAll(RegExp(r'[^0-9]'), '');
    if (barcode.length != 14) return null;

    final core13 = barcode.substring(0, 13);
    final expected = _computeGs1CheckDigit(core13);
    final actual = int.tryParse(barcode.substring(13));
    if (actual == null || expected != actual) return null;

    return encodeSgtin96FromGtin14(barcode);
  }

  static int _bitsToInt(String value) => int.parse(value, radix: 2);
  static String _toBits(int value, int width) =>
      value.toRadixString(2).padLeft(width, '0');

  static int _computeGs1CheckDigit(String gtinWithoutCheck) {
    var sum = 0;
    for (var i = 0; i < gtinWithoutCheck.length; i++) {
      final digit = int.parse(gtinWithoutCheck[gtinWithoutCheck.length - 1 - i]);
      sum += (i.isEven ? 3 : 1) * digit;
    }
    return (10 - (sum % 10)) % 10;
  }
}
