library requests;

import 'dart:io';
import 'dart:json' as JSON;
import 'dart:async';
import 'package:logging/logging.dart';

Logger LOG = new Logger('requests');

class ValueNotPassedSentinel {

}

class Content {
  ContentType type;
  Stream<List<int>> data;
  int length;
  
  Content();
  
  factory Content.forString(String value, type, [encoding = Encoding.UTF_8]) {
    Content c = new Content();
    c.type = type;
    final encoder = new StringEncoder();
    c.data = encoder.bind
      (new Stream<String>.fromIterable
        ([value]));
  }

  factory Content.forJson(dynamic obj) {
    return new Content.forString
      ( JSON.stringify(data)
      , ContentType.parse('application/json'));
  }
  
  write(HttpClientRequest req) {
    req.addStream(data);
    req.headers.set(HttpHeaders.CONNECTION, 'close');
    req.headers.set(HttpHeaders.CONTENT_LENGTH, data.length);
    req.headers.set(HttpHeaders.TRANSFER_ENCODING, 'chunked');
    req.headers.set(HttpHeaders.CONTENT_TYPE, type.toString());
  }
}


class Request {

  HttpClient client = new HttpClient();
  String method;
  Uri uri;
  Content data = new Content();
  List<Cookie> cookies = <Cookie>[];
  Map<String, String> headers = <String, String>{};
  Map<String, String> params = <String, String>{};

  Uri get actualUri {
    return mergeArgs(uri, params);
  }

  prepareRequest(HttpClientRequest req) {
    if (data != null) {
      data.write(req);
    }
    return req.close();
  }

  Future<Response> onResponse(HttpClientResponse raw) {
    final resp = new Response(raw);
    return resp.finished.future;
  }
  
  onError(e) {
    print(e);
  }

  Future<Response> execute2() {
    var conn = client.openUrl(method, actualUri);
    return conn.then(prepareRequest).then(onResponse);
  }
  
  Future<Response> execute([HttpClient perRequestClient]) => 
    client.openUrl(method, actualUri)
      .then(prepareRequest, onError: onError)
      .then(onResponse, onError: onError);
}

class Response {

  final HttpClientResponse raw;
  final Completer finished = new Completer();
  
  String _content;
  
  Response(this.raw) {
    final b = new StringBuffer();
    stringStream.listen(
        (data) => b.write(data),
        onDone: () {
          _content = b.toString();
          finished.complete(this);
        }
    );
  }
  
  Stream<String> get stringStream => new StringDecoder().bind(raw);
  
  String get content => _content;
  
  dynamic get json => JSON.parse(content);

}

//class _Response {
//
//  Request request;
//  HttpClientResponse raw;
//
//  final _bodyBuffer = new StringBuffer();
//
//  final Completer<Response> _finished = new Completer<Response>();
//
//  Response();
//
//  HttpHeaders get headers => raw.headers;
//  List<Cookie> get cookies => raw.cookies;
//  int get statusCode => raw.statusCode;
//
//  _bind(request, raw) {
//    this.request = request;
//    this.raw = raw;
//    if (request.stream) {
//      _finished.complete(this);
//    }
//    else {
//      raw.inputStream.onData = _onData;
//      raw.inputStream.onClosed = _onClosed;
//    }
//
//  }
//
//  _onData() {
//    var data = raw.inputStream.read(1024);
//    data.forEach((c) => _bodyBuffer.addCharCode(c));
//  }
//
//  _onClosed() {
//    _finished.complete(this);
//  }
//
//  String get content {
//    return _bodyBuffer.toString();
//  }
//
//  dynamic get json {
//    return JSON.parse(content);
//  }
//
//}


Uri mergeArgs(Uri original, Map<String, String> args) {
  Map oldArgs = original.queryParameters;
  Map newArgs = new Map.from(args);
  oldArgs.forEach((k, v) => newArgs[k] = v);
  print(newArgs);
  return new Uri
    ( scheme          : original.scheme
    , userInfo        : original.userInfo
    , host            : original.host
    , port            : original.port
    , path            : original.path
    , queryParameters : newArgs
    , fragment        : original.fragment
    );
}

Future<Response> request
    ( method
    , uri
    ,
    { Map<String, String> params : const <String, String>{}
    , Content data
    , Map<String, String> headers 
    , List<Cookie> cookies
    , List<String> parts
    }) {
  Request r = new Request();
  r.method = method;
  if (uri is String) {
    uri = Uri.parse(uri);
  }
  r.uri = uri;
  r.params = params;
  r.data = data;
  r.headers = headers;
  r.cookies = cookies;
  return r.execute();
}

main() {
  var u = 'https://www.googleapis.com/discovery/v1/apis/urlshortener/v1/rest';
  request('GET', u, params: {'prettyprint': 'true'}).then((Response resp) {
    print(resp.json);
  });
}