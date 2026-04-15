import 'package:dart_frog/dart_frog.dart';

Response onRequest(RequestContext context) {
  return Response.json(
    body: {
      'name': 'Scan System API',
      'version': '1.0.0',
      'status': 'running',
    },
  );
}
