String hms(int s) {
  final h = s ~/ 3600, m = (s % 3600) ~/ 60, x = s % 60;
  String p(int v) => v.toString().padLeft(2, '0');
  return '${p(h)}:${p(m)}:${p(x)}';
}

String fmt(int n) {
  final s = n.abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return '${n < 0 ? '-' : ''}$b';
}

String ago(DateTime t) {
  final m = DateTime.now().difference(t).inMinutes;
  if (m < 1) return 'just now';
  if (m < 60) return '$m min ago';
  if (m < 1440) return '${(m / 60).round()} h ago';
  return '${(m / 1440).round()} d ago';
}
