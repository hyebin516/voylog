import 'package:flutter/material.dart';

class DateRangeResult {
  final DateTime startDate;
  final DateTime endDate;

  const DateRangeResult({required this.startDate, required this.endDate});
}

/// A single combined start+end date range picker (large calendar, Korean-
/// localized via the app's ambient locale) -- used for setting a trip's
/// date range, whether at creation or editing it later.
Future<DateRangeResult?> showTripDateRangeDialog(
  BuildContext context, {
  DateTime? initialStartDate,
  DateTime? initialEndDate,
  String title = '여행 날짜',
}) async {
  final initialRange = (initialStartDate != null && initialEndDate != null)
      ? DateTimeRange(start: initialStartDate, end: initialEndDate)
      : null;

  final picked = await showDateRangePicker(
    context: context,
    firstDate: DateTime(2020),
    lastDate: DateTime(2100),
    initialDateRange: initialRange,
    initialEntryMode: DatePickerEntryMode.calendarOnly,
    helpText: title,
    saveText: '확인',
    cancelText: '취소',
  );
  if (picked == null) return null;

  return DateRangeResult(startDate: picked.start, endDate: picked.end);
}
