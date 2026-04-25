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

  static EpcConverterResult? tryConvertToEpc(String raw) {
    final barcode = raw.trim().replaceAll(RegExp(r'[^0-9]'), '');
    if (barcode.length != 14) return null;

    final core13 = barcode.substring(0, 13);
    final expected = _computeGs1CheckDigit(core13);
    final actual = int.tryParse(barcode.substring(13));
    if (actual == null || expected != actual) return null;

    final partition = _digitsToPartition[_companyPrefixDigits] ?? 5;
    final (cpBits, cpDigits, itemBits, itemDigits) = _partitionTable[partition];
    final companyPrefix = core13.substring(0, cpDigits);
    final itemReference = core13.substring(cpDigits, cpDigits + itemDigits);

    final cpValue = int.parse(companyPrefix);
    final itemValue = int.parse(itemReference);

    final serial = BigInt.parse(barcode) % (BigInt.one << 38);
    final bits =
        _toBits(_sgtin96Header, 8) +
        _toBits(_defaultFilter, 3) +
        _toBits(partition, 3) +
        _toBits(cpValue, cpBits) +
        _toBits(itemValue, itemBits) +
        serial.toRadixString(2).padLeft(38, '0');

    final epc = BigInt.parse(bits, radix: 2).toRadixString(16).toUpperCase().padLeft(24, '0');
    return EpcConverterResult(
      value: epc,
      message: 'Barcode хувиргав: $barcode -> $epc (CP:$cpDigits)',
    );
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
