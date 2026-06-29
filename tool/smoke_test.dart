import 'dart:io';

import 'package:alkokh_mobile_sdk/alkokh_mobile_sdk.dart';

Future<void> main() async {
  final baseUrl =
      Platform.environment['ALKOKH_BASE_URL'] ?? 'http://178.105.22.175:8002';
  final phone = Platform.environment['ALKOKH_PHONE'] ?? '07700000001';
  final password = Platform.environment['ALKOKH_PASSWORD'] ?? 'Mobile@1234';
  final quoteItem = Platform.environment['ALKOKH_SMOKE_QUOTE_ITEM'];

  var requestCounter = 0;
  final client = AlkokhMobileClient(
    baseUrl: baseUrl,
    tokenStore: MemoryTokenStore(),
    requestIdProvider: () =>
        'sdk-smoke-${DateTime.now().millisecondsSinceEpoch}-${++requestCounter}',
  );

  var signedIn = false;
  try {
    final session = await client.signIn(phone: phone, password: password);
    signedIn = true;
    _ok('signed in as ${session.user ?? session.fullName ?? phone}');

    final config = await client.getConfig();
    _ok('config currency=${config.currency}');

    final home = await client.getHome();
    _ok('home sections=${home.sections.length}');

    final products = await client.listProducts(limit: 5);
    _ok('products=${products.items.length}');

    final profile = await client.getMe();
    _ok('profile guardian=${profile.guardianId ?? '-'}');

    final pets = await client.listPets(limit: 5, includeDisabled: true);
    _ok('pets=${pets.items.length}');

    if (quoteItem != null && quoteItem.trim().isNotEmpty) {
      final quote = await client.quoteOrder(
        items: [MobileOrderItem(itemCode: quoteItem.trim(), qty: 1)],
      );
      _ok('quote total=${quote.grandTotal} canPlace=${quote.canPlaceOrder}');
    } else {
      _ok('quote skipped; set ALKOKH_SMOKE_QUOTE_ITEM to test checkout quote');
    }
  } on AlkokhMobileException catch (error) {
    stderr.writeln('[fail] ${error.code}: ${error.message}');
    exitCode = 1;
  } finally {
    if (signedIn) {
      await client.signOut();
    }
    client.close();
  }
}

void _ok(String message) {
  stdout.writeln('[ok] $message');
}
