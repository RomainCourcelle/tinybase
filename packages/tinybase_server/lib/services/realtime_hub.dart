import 'dart:async';
import 'dart:convert';

/// Événement diffusé aux abonnés SSE d'une collection.
class RecordChangeEvent {
  final String collection;
  final String action; // create | update | delete
  final String recordId;
  final Map<String, dynamic>? record;

  const RecordChangeEvent({
    required this.collection,
    required this.action,
    required this.recordId,
    this.record,
  });

  Map<String, dynamic> toJson() => {
        'action': action,
        'recordId': recordId,
        if (record != null) 'record': record,
      };

  String toSse() {
    final data = jsonEncode(toJson());
    return 'event: record\ndata: $data\n\n';
  }
}

/// Bus in-process pour le temps réel (SSE). Une instance unique par process.
class RealtimeHub {
  final Map<String, StreamController<RecordChangeEvent>> _channels = {};

  /// S'abonne aux changements de [collection].
  Stream<RecordChangeEvent> subscribe(String collection) {
    final channel = _channels.putIfAbsent(
      collection,
      () => StreamController<RecordChangeEvent>.broadcast(
        onCancel: () {
          final c = _channels.remove(collection);
          c?.close();
        },
      ),
    );
    return channel.stream;
  }

  void emit(RecordChangeEvent event) {
    final channel = _channels[event.collection];
    if (channel == null || channel.isClosed) return;
    channel.add(event);
  }
}
