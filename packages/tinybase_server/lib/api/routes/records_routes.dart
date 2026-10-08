import 'dart:async';
import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../../services/realtime_hub.dart';
import '../../services/records_service.dart';
import '../json_response.dart';
import '../middleware/auth_middleware.dart';
import '../multipart.dart';

/// Routes REST génériques, montées une seule fois sous `/api/collections`
/// (voir app.dart) avec le nom de la collection en paramètre d'URL.
///
///   GET    /api/collections/<name>/records
///   GET    /api/collections/<name>/records/<id>
///   POST   /api/collections/<name>/records
///   PATCH  /api/collections/<name>/records/<id>
///   DELETE /api/collections/<name>/records/<id>
///   GET    /api/collections/<name>/records/<id>/files/<field>
///   GET    /api/collections/<name>/realtime
Router buildRecordsRoutes(RecordsService recordsService, RealtimeHub realtimeHub) {
  final router = Router();

  router.get('/<name>/records', (Request request, String name) async {
    try {
      final params = request.url.queryParameters;
      final result = await recordsService.list(
        name,
        auth: request.auth,
        filter: params['filter'] ?? '',
        sort: params['sort'] ?? '',
        page: int.tryParse(params['page'] ?? '') ?? 1,
        perPage: int.tryParse(params['perPage'] ?? '') ?? 30,
      );
      return jsonResponse({
        'page': result.page,
        'perPage': result.perPage,
        'totalItems': result.totalItems,
        'items': result.items,
      });
    } catch (e) {
      return errorResponse(e);
    }
  });

  router.get('/<name>/records/<id>', (Request request, String name, String id) async {
    try {
      final record = await recordsService.view(name, id, auth: request.auth);
      return jsonResponse(record);
    } catch (e) {
      return errorResponse(e);
    }
  });

  router.get('/<name>/records/<id>/files/<field>', (Request request, String name, String id, String field) async {
    try {
      final file = await recordsService.readFile(name, id, field, auth: request.auth);
      return Response.ok(
        file.bytes,
        headers: {
          'content-type': file.contentType ?? 'application/octet-stream',
          'content-disposition': 'inline; filename="${file.storedName}"',
        },
      );
    } catch (e) {
      return errorResponse(e);
    }
  });

  router.get('/<name>/realtime', (Request request, String name) async {
    try {
      final decision = await recordsService.authorizeRealtimeAsync(name, request.auth);
      if (!decision.allowed) throw ForbiddenException();

      StreamSubscription<RecordChangeEvent>? sub;
      Timer? pingTimer;
      final controller = StreamController<List<int>>(
        onCancel: () async {
          pingTimer?.cancel();
          await sub?.cancel();
        },
      );

      sub = realtimeHub.subscribe(name).listen((event) {
        if (!recordsService.eventVisibleTo(decision, request.auth, event)) return;
        if (!controller.isClosed) {
          controller.add(utf8.encode(event.toSse()));
        }
      });

      controller.add(utf8.encode(': connected\n\n'));
      pingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
        if (!controller.isClosed) {
          controller.add(utf8.encode(': ping\n\n'));
        }
      });

      return Response.ok(
        controller.stream,
        headers: {
          'content-type': 'text/event-stream; charset=utf-8',
          'cache-control': 'no-cache',
          'connection': 'keep-alive',
          'x-accel-buffering': 'no',
        },
      );
    } catch (e) {
      return errorResponse(e);
    }
  });

  router.post('/<name>/records', (Request request, String name) async {
    try {
      final body = await readRecordBody(request);
      final record = await recordsService.create(
        name,
        body.data,
        auth: request.auth,
        files: body.files,
      );
      return jsonResponse(record, status: 201);
    } catch (e) {
      return errorResponse(e);
    }
  });

  router.patch('/<name>/records/<id>', (Request request, String name, String id) async {
    try {
      final body = await readRecordBody(request);
      final record = await recordsService.update(
        name,
        id,
        body.data,
        auth: request.auth,
        files: body.files,
      );
      return jsonResponse(record);
    } catch (e) {
      return errorResponse(e);
    }
  });

  router.delete('/<name>/records/<id>', (Request request, String name, String id) async {
    try {
      await recordsService.delete(name, id, auth: request.auth);
      return jsonResponse({'ok': true});
    } catch (e) {
      return errorResponse(e);
    }
  });

  return router;
}
