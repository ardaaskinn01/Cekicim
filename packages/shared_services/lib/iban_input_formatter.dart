import 'package:flutter/services.dart';

/// TR IBAN Formatter:
/// Strictly caps input at 26 raw alphanumeric characters (TR + 24 digits).
/// Formats into 4-char groups: TR00 0000 0000 0000 0000 0000 00 (max 32 chars with spaces).
/// Any extra characters typed beyond 26 raw characters are blocked/discarded.
class IbanInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String raw = newValue.text.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();

    // Cap raw characters at max 26 (TR + 24 digits)
    if (raw.length > 26) {
      raw = raw.substring(0, 26);
    }

    final buffer = StringBuffer();
    for (int i = 0; i < raw.length; i++) {
      if (i > 0 && i % 4 == 0) {
        buffer.write(' ');
      }
      buffer.write(raw[i]);
    }

    final formatted = buffer.toString();

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
