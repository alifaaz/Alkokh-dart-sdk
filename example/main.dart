import 'package:alkokh_mobile_sdk/alkokh_mobile_sdk.dart';

Future<void> main() async {
  const config = AlkokhMobileConfig(
    scheme: 'http',
    host: '178.105.22.175',
    port: 8002,
    cacheEnabled: true,
  );
  final client = AlkokhMobileClient(
    config: config,
    tokenStore: MemoryTokenStore(),
  );
  try {
    final session = await client.signIn(
      phone: '07700000001',
      password: 'Mobile@1234',
    );
    print('Signed in as ${session.user ?? session.fullName ?? 'mobile user'}');

    final orders = await client.listOrders();
    print('Loaded ${orders.items.length} orders');
  } finally {
    client.close();
  }
}
