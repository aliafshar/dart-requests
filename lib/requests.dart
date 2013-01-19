
import 'dart:io';
import 'dart:uri';
import 'dart:json';



abstract class Data {
  ContentType contentType;
  InputStream stream;
  int contentLength;
}


class StringData implements Data {

  final ContentType contentType;
  final InputStream stream = new ListInputStream();
  int contentLength;

  StringData(String data, this.contentType, [encoding = Encoding.UTF_8]) {
    ListInputStream s = stream;
    s.write(data.charCodes);
    contentLength = data.charCodes.length;
  }

}


class JsonData extends StringData {

  JsonData(dynamic data) :
    super( JSON.stringify(data)
         , new ContentType.fromString('application/json'));
}


class StreamData implements Data {

  final InputStream stream;
  final ContentType contentType;

  StreamData(this.stream, this.contentType);

}


class Request {

  String method;
  String url;
  Data data;
  List<Cookie> cookies;
  Map<String, String> params;
  Map<String, String> headers;
  bool stream;
  List<String> parts;
  List<InputStream> partStreams;

  HttpClient client = new HttpClient();
  HttpClientRequest raw;

  Response response = new Response();

  Completer<Response> finished = new Completer<Response>();

  Request
    ( this.method
    , this.url
    ,
    { Map<String, String> params
    , this.data
    , Map<String, String> headers
    , List<Cookie> cookies
    , List<String> parts
    , List<InputStream> partStreams
    , this.stream : false
    }) {
    this.params = (params != null) ? params : <String>{};
    this.headers = (headers != null) ? headers : <String>{};
    this.cookies = (cookies != null) ? cookies : <Cookie>[];
    this.parts = (parts != null) ? parts : <String>[];
    this.partStreams = (partStreams != null) ? partStreams : <InputStream>[];
  }

  Uri get actualUrl {
    return mergeArgs(new Uri(url), params);
  }

  Future<Response> execute() {
    var conn = client.openUrl(method, actualUrl);
    conn.onError = _onError;
    conn.onResponse = _onResponse;
    conn.onRequest = _onRequest;
    response._finished.future.then((response) {
      finished.complete(response);
      client.shutdown();
    });
    return finished.future;
  }

  _onRequest(HttpClientRequest raw) {
    this.raw = raw;
    if (data != null) {
      raw.headers.set(HttpHeaders.CONNECTION, 'close');
      raw.headers.set(HttpHeaders.CONTENT_LENGTH, data.contentLength);
      raw.headers.set(HttpHeaders.TRANSFER_ENCODING, 'chunked');
      raw.headers.set(HttpHeaders.CONTENT_TYPE, data.contentType.toString());
      data.stream.pipe(raw.outputStream);
      //raw.outputStream.write(data.stream.read());
    } else {
      raw.outputStream.close();
    }
  }

  _onClosed() {
    print('closed');
  }

  _onResponse(HttpClientResponse raw) {
    response._bind(this, raw);
  }

  _onError(var e) {
    print(e);
  }

}

class Response {

  Request request;
  HttpClientResponse raw;

  final _bodyBuffer = new StringBuffer();

  final Completer<Response> _finished = new Completer<Response>();

  Response();

  HttpHeaders get headers => raw.headers;
  List<Cookie> get cookies => raw.cookies;
  int get statusCode => raw.statusCode;

  _bind(request, raw) {
    this.request = request;
    this.raw = raw;
    if (request.stream) {
      _finished.complete(this);
    }
    else {
      raw.inputStream.onData = _onData;
      raw.inputStream.onClosed = _onClosed;
    }

  }

  _onData() {
    var data = raw.inputStream.read(1024);
    data.forEach((c) => _bodyBuffer.addCharCode(c));
  }

  _onClosed() {
    _finished.complete(this);
  }

  String get content {
    return _bodyBuffer.toString();
  }

  dynamic get json {
    return JSON.parse(content);
  }

}

Map<String, String> splitQueryString(String queryString) {
    Map<String, String> result = new Map<String, String>();
    int currentPosition = 0;
    while (currentPosition < queryString.length) {
      int position = queryString.indexOf("=", currentPosition);
      if (position == -1) {
        break;
      }
      String name = queryString.substring(currentPosition, position);
      currentPosition = position + 1;
      position = queryString.indexOf("&", currentPosition);
      String value;
      if (position == -1) {
        value = queryString.substring(currentPosition);
        currentPosition = queryString.length;
      } else {
        value = queryString.substring(currentPosition, position);
        currentPosition = position + 1;
      }
      result[decodeUriComponent(name)] = decodeUriComponent(value);
    }
    return result;
  }

String buildQueryString(Map<String, String> data) {
  return Strings.join(data.keys.map((k) {
    return '${encodeUriComponent(k)}=${encodeUriComponent(data[k])}';
  }), "&");
}

Uri mergeArgs(Uri original, Map<String, String> args) {
  Map originalArgs = splitQueryString(original.query);
  Map newArgs = new Map.from(args);
  originalArgs.forEach((k, v) => newArgs[k] = v);
  return new Uri.fromComponents
     ( scheme   : original.scheme
     , userInfo : original.userInfo
     , domain   : original.domain
     , port     : original.port
     , path     : original.path
     , query    : buildQueryString(newArgs)
     , fragment : original.fragment
     );
}

Future<Response> request
    ( method
    , url
    ,
    { Map<String, String> params
    , Data data
    , Map<String, String> headers
    , List<Cookie> cookies
    , List<String> parts
    , List<InputStream> partStreams
    }) {

  var r = new Request( method, url
                     , params: params
                     , data: data
                     , headers: headers
                     , cookies: cookies
                     , parts: parts
                     , partStreams: partStreams
                     );
  return r.execute();
}

main() {
  SecureSocket.initialize();
  var u = 'https://www.googleapis.com/discovery/v1/apis/urlshortener/v1/rest';
  //request('GET', u).then((resp) => print(resp.json));
  request('POST', 'http://localhost:8000',
      data : new JsonData({'a':'b'})).then((resp) => print(resp.content));
}