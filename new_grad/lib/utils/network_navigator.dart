import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../pages/offline_page.dart';

Future<bool> _hasInternet() async {
  try {
    final result = await http
        .get(Uri.parse('https://www.google.com'))
        .timeout(const Duration(seconds: 5));
    return result.statusCode == 200;
  } catch (_) {
    return false;
  }
}

Future<void> navigateWithNetworkCheck(
  BuildContext context,
  String route, {
  Object? arguments,
}) async {
  final online = await _hasInternet();
  if (!context.mounted) return;

  if (!online) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            OfflinePage(returnRoute: route, returnArguments: arguments),
      ),
    );
  } else {
    Navigator.pushNamed(context, route, arguments: arguments);
  }
}
