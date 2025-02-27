import 'dart:convert';
import 'dart:io';

import 'package:json_api_document/json_api_document.dart';
import 'package:json_api_server/src/controller.dart';
import 'package:json_api_server/src/document_builder.dart';
import 'package:json_api_server/src/response.dart';
import 'package:json_api_server/src/routing.dart';

class Server {
  final Routing routing;
  final Controller controller;
  final DocumentBuilder builder;
  final String allowOrigin;

  Server(this.routing, this.controller, {this.allowOrigin = '*'})
      : builder = DocumentBuilder(routing);

  Future process(HttpRequest http) async {
    final target = routing.getTarget(http.requestedUri);
    if (target == null) {
      return _send(http, ErrorResponse.badRequest([]));
    } else if (!controller.supportsType(target.type)) {
      return _send(
          http,
          ErrorResponse.notFound(
              [JsonApiError(detail: 'Unknown resource type')]));
    }

    final request = target.getRequest(http.method);
    if (request == null) {
      return _send(http, ErrorResponse.methodNotAllowed([]));
    }

    final body = await http.transform(utf8.decoder).join();

    await request.call(controller, http.requestedUri.queryParametersAll,
        body.isNotEmpty ? json.decode(body) : null);

    return _send(http, request.response);
  }

  Future _send(HttpRequest http, Response response) {
    http.response.statusCode = response.status;
    response.getHeaders(routing).forEach(http.response.headers.add);
    if (allowOrigin != null) {
      http.response.headers.add('Access-Control-Allow-Origin', allowOrigin);
    }
    final doc = response.getDocument(builder, http.requestedUri);
    if (doc != null) {
      http.response.write(json.encode(doc));
    }
    return http.response.close();
  }
}
