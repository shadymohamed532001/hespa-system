import 'package:intl/intl.dart';

final _dateTime = DateFormat('dd/MM/yyyy  hh:mm a', 'ar');
final _dateOnly = DateFormat('dd/MM/yyyy', 'ar');

/// Full date + time for every transaction display across the app.
String formatDateTime(dynamic value) {
  final parsed = DateTime.tryParse('$value')?.toLocal();
  return parsed == null ? '—' : _dateTime.format(parsed);
}

String formatDate(dynamic value) {
  final parsed = DateTime.tryParse('$value')?.toLocal();
  return parsed == null ? '—' : _dateOnly.format(parsed);
}
