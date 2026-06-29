# Alkokh Mobile SDK

Pure Dart SDK for the currently implemented Alkokh mobile API.

The SDK hides Frappe method URLs and response wrappers from the Flutter app. It treats OAuth access tokens as opaque strings and keeps mobile orders mapped to ERPNext `Sales Order`.

## Usage

Install from GitHub in the Flutter app:

```yaml
dependencies:
  alkokh_mobile_sdk:
    git:
      url: https://github.com/alifaaz/Alkokh-dart-sdk.git
      ref: main
```

```dart
import 'package:alkokh_mobile_sdk/alkokh_mobile_sdk.dart';

final sdkConfig = AlkokhMobileConfig(
  baseUrl: appConfig.apiBaseUrl,
  requestIdProvider: () => 'mobile-${DateTime.now().microsecondsSinceEpoch}',
);

final client = AlkokhMobileClient(
  config: sdkConfig,
  tokenStore: MemoryTokenStore(),
);

final session = await client.signIn(
  phone: '07700000001',
  password: 'Mobile@1234',
);

final orders = await client.listOrders();
final home = await client.getHome();
final products = await client.listProducts(category: 'Products');
final favorites = await client.listFavorites();
final pets = await client.listPets();
final addresses = await client.listAddresses();
final quote = await client.quoteOrder(
  items: const [MobileOrderItem(itemCode: 'ITEM-001', qty: 2)],
);
```

For Flutter, use `KeyValueTokenStore` with `flutter_secure_storage` and pass it to `AlkokhMobileClient`. See [docs/mobile_team_usage.md](docs/mobile_team_usage.md).

## Implemented Areas

- Auth: sign up, sign in, refresh, sign out, password reset.
- Profile: current mobile Guardian profile, profile update, password change, phone change, avatar upload, account delete.
- Addresses: list, create, update, default, soft-delete, supported cities, reverse placeholder.
- Config/content: app config, support contact, static content placeholders.
- Catalog/search: home, products, product detail, categories, brands, search, suggestions.
- Favorites/reviews/recent search: favorite toggle/list/remove, product review list/upsert, recent search list/save/clear.
- Devices: register/delete FCM device tokens; no push sending yet.
- Pets: list, detail, create, update, disable/archive, photo upload, medical timeline, documents, vaccination/deworming CRUD.
- Orders: quote frontend cart, place cash-only Sales Order, list, detail, cancel, reorder draft.
- Debugging: optional `X-Request-Id` provider.
- Upload UX: avatar and pet photo upload progress callbacks.
- Token storage: pure-Dart `KeyValueTokenStore` adapter for secure storage plugins.

Orders are still backend `Sales Order` records. The SDK does not create or expect a separate Order model.
Payment is currently cash-only; `placeOrder` sends `Cash on Delivery`.

## Test

```bash
dart pub get
dart test
dart analyze
```

## Smoke Test

```bash
dart run tool/smoke_test.dart
```
