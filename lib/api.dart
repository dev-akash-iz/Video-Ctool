import 'package:dio/dio.dart';

// initaling dio object and reuse that all time

// we can  also implement intermediater currenty not used that
final dio = Dio();

const String googleScriptUrl =
    'https://script.google.com/macros/s/AKfycbwzrvcP7xSXQcuHm83Jt4rysirXVt9O20wLmr4MCUpbpwxn21FNIxRcJQ5nK0l1u5C_/exec';

Future<List<dynamic>> requestCommandList() async {
  Response response; 
  // The below request is the same as above.
  try {
    response = await dio.get(googleScriptUrl);
    return response.data?['result'] ?? [];
  } catch (e) {
    return [];
  }
}

Future<bool> addCommand(
    {String? title, String? command, String? description}) async {
  Response response;
  // The below request is the same as above.
  try {
    response = await dio.get(googleScriptUrl, queryParameters: {
      "action": "a",
      "tittle": title,
      "command": command,
      "description": description
    });
    return response.data?['status'];
  } catch (e) {
    return false;
  }
}
