const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "Just now", "5 min ago", "3 h ago", "Yesterday", then "12 Nov 2026".
String formatRelativeDate(DateTime date, {DateTime? now}) {
  final local = date.toLocal();
  final reference = now ?? DateTime.now();
  final diff = reference.difference(local);

  if (diff.isNegative || diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24 && local.day == reference.day) return '${diff.inHours} h ago';

  final yesterday = DateTime(reference.year, reference.month, reference.day - 1);
  if (local.year == yesterday.year && local.month == yesterday.month && local.day == yesterday.day) {
    return 'Yesterday, ${_time(local)}';
  }
  return formatDate(local);
}

/// "12 Nov 2026, 14:05"
String formatDateTime(DateTime date) {
  final local = date.toLocal();
  return '${formatDate(local)}, ${_time(local)}';
}

String formatDate(DateTime date) {
  final local = date.toLocal();
  return '${local.day} ${_months[local.month - 1]} ${local.year}';
}

String _time(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
