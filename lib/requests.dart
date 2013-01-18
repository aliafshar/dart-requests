
import 'dart:io';
import 'dart:uri';


class Request {

  String method;
  String url;
  String data;
  List<Cookie> cookies;
  Map<String, String> params;
  Map<String, String> headers;
  List<String> parts;
  List<InputStream> partStreams;
  HttpClient client = new HttpClient();

  Request
    ( this.method
    , this.url
    ,
    { Map<String, String> params
    , this.data
    , InputStream dataStream
    , Map<String, String> headers
    , List<Cookie> cookies
    , List<String> parts
    , List<InputStream> partStreams
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

  execute() {
    var conn = client.openUrl(method, actualUrl);
    conn.onError = onError;
    conn.onResponse = onResponse;
    conn.onRequest = onRequest;
  }

  onRequest(HttpClientRequest request) {

  }


  onResponse(HttpClientResponse response) {

  }

  onError(Exception e) {

  }

}

class Response {

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
    , String data
    , InputStream dataStream
    , Map<String, String> headers
    , List<Cookie> cookies
    , List<String> parts
    , List<InputStream> partStreams
    }) {

  var r = new Request( method, url
                      , params: params
                      , data: data
                      , dataStream: dataStream
                      , headers: headers
                      , cookies: cookies
                      , parts: parts
                      , partStreams: partStreams
                      );
  print(r.params);
  print(r.headers);
}

main() {
  var u = 'http://google.com?banana=lemon';
  request('GET', u, params : {'a': 'b'});
}