import 'package:alkokh_mobile_sdk/alkokh_mobile_sdk.dart';

Future<void> main() async {
  const config = AlkokhMobileConfig(baseUrl: 'http://178.105.22.175:8002');
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
