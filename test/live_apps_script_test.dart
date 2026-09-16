import 'dart:convert';

import 'package:crm/api_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Apps Script web app returns users after its content redirect', () async {
    const endpoint =
        'https://script.google.com/macros/s/AKfycbxUpfSmsAk_jMjDCVqMoZ5SEeJAUtL14chAQBvv90fmg6Tbu5iwCw9AhHZ57EJeoOXS/exec';
    final response = await const ApiClient().post(
      Uri.parse(endpoint),
      headers: const {'content-type': 'application/json; charset=utf-8'},
      body: jsonEncode({'operation': 'listUsers'}),
      retries: 0,
    );

    expect(response.statusCode, 200);
    expect(jsonDecode(response.body), contains('users'));
  });
}
