/// Change event received from a collection SSE stream.
class RecordChange {
  /// `create`, `update` or `delete`.
  final String action;

  /// Id of the affected record.
  final String recordId;

  /// Full record payload (absent on `delete`).
  final Map<String, dynamic>? record;

  /// Creates a change event.
  const RecordChange({
    required this.action,
    required this.recordId,
    this.record,
  });

  /// Parses a JSON object from an SSE `data:` line.
  factory RecordChange.fromJson(Map<String, dynamic> json) {
    return RecordChange(
      action: json['action'] as String,
      recordId: json['recordId'] as String,
      record: json['record'] is Map
          ? Map<String, dynamic>.from(json['record'] as Map)
          : null,
    );
  }
}
