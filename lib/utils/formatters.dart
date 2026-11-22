// Display formatting for prices and amounts.
//
// - Thousands separators: 351750 -> 351,750.00
// - EGX tick precision: 2 decimals, 3 decimals below 1 EGP
// - Left-to-right isolation, so "+3.3%" is not shown as "3.3%+" inside Arabic text

const String _lri = '⁦'; // LEFT-TO-RIGHT ISOLATE
const String _pdi = '⁩'; // POP DIRECTIONAL ISOLATE

/// Forces [s] to display left-to-right inside right-to-left text.
String ltr(String s) => '$_lri$s$_pdi';

/// 1234567.891 -> "1,234,567.89"
String fmtNum(num v, [int decimals = 2]) {
  final s = v.abs().toStringAsFixed(decimals);
  final parts = s.split('.');
  final intPart = parts[0];
  final buf = StringBuffer();
  for (var i = 0; i < intPart.length; i++) {
    if (i > 0 && (intPart.length - i) % 3 == 0) buf.write(',');
    buf.write(intPart[i]);
  }
  var out = buf.toString();
  if (parts.length > 1) out = '$out.${parts[1]}';
  final isZero = double.parse(s) == 0;
  return (v < 0 && !isZero) ? '-$out' : out;
}

/// Share price at EGX tick precision.
String fmtPrice(num v) => fmtNum(v, v.abs() < 1 ? 3 : 2);

/// Signed number: "+2.20" / "-2.20" / "0.00".
String fmtSigned(num v, [int decimals = 2]) {
  final s = fmtNum(v, decimals);
  return ltr((v > 0 && double.parse(v.abs().toStringAsFixed(decimals)) != 0) ? '+$s' : s);
}

/// Signed percentage: "+2.68%" / "-0.40%".
String fmtPct(num v, [int decimals = 2]) {
  final s = fmtNum(v, decimals);
  return ltr((v > 0 && double.parse(v.abs().toStringAsFixed(decimals)) != 0) ? '+$s%' : '$s%');
}
