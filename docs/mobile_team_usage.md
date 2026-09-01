# Alkokh Mobile SDK Usage

> Backend contract source: `apps/pet_app/docs/MOBILE_API_README.md` in the backend repo. This SDK usage guide is a consumer note; if it conflicts with the backend contract, the backend contract wins.

The SDK talks to Frappe method endpoints internally. The Flutter app should use SDK methods directly and should not build `/v1/...` REST paths.

## Install

Install from GitHub in the Flutter app:

```yaml
dependencies:
  alkokh_mobile_sdk:
    git:
      url: https://github.com/alifaaz/Alkokh-dart-sdk.git
      ref: master
```

For local development, the Flutter app can temporarily use `path: ../packages/alkokh_mobile_sdk`.

## External App Config

Keep backend values in the Flutter app configuration layer, then pass them into the SDK:

```dart
final sdkConfig = AlkokhMobileConfig(
  scheme: appConfig.apiScheme,
  host: appConfig.apiHost,
  port: appConfig.apiPort,
  cacheEnabled: appConfig.cacheEnabled,
  cacheTtl: const Duration(minutes: 5),
  requestIdProvider: () => appConfig.nextRequestId(),
);
```

If the app already stores a full URL, `baseUrl: appConfig.apiBaseUrl` is still supported and takes precedence over `scheme`, `host`, and `port`.

## Secure Token Storage

The SDK stays pure Dart, so it does not depend on Flutter plugins directly. In Flutter, add `flutter_secure_storage` in the app and plug it into `KeyValueTokenStore`:

```dart
import 'package:alkokh_mobile_sdk/alkokh_mobile_sdk.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const secureStorage = FlutterSecureStorage();

final tokenStore = KeyValueTokenStore(
  readValue: (key) => secureStorage.read(key: key),
  writeValue: (key, value) => secureStorage.write(key: key, value: value),
  deleteValue: (key) => secureStorage.delete(key: key),
);

final client = AlkokhMobileClient(
  config: sdkConfig,
  tokenStore: tokenStore,
);
```

## Optional Persistent Cache

When `cacheEnabled` is true, the SDK uses `MemoryCacheStore` unless the app provides a cache store. For persistence across app restarts, plug any Flutter key-value storage into `KeyValueCacheStore`:

```dart
final cacheStore = KeyValueCacheStore(
  readValue: (key) => sharedPreferencesAsync.getString(key),
  writeValue: (key, value) => sharedPreferencesAsync.setString(key, value),
  deleteValue: (key) => sharedPreferencesAsync.remove(key),
);

final client = AlkokhMobileClient(
  config: sdkConfig,
  tokenStore: tokenStore,
  cacheStore: cacheStore,
);
```

The default cache scope is safe public reads only: config, support/content, home, catalog, search, suggestions, and product reviews. Auth, profile, addresses, pets, favorites, orders, devices, uploads, and all `POST` calls are not cached by default.

Use `forceRefresh: true` to bypass cache for a single read:

```dart
final products = await client.listProducts(
  limit: 20,
  cursor: nextCursor,
  forceRefresh: true,
);
```

## Home Blocks

Use the block-based home method for the mobile home screen:

```dart
final home = await client.getHome();

for (final block in home.blocks) {
  final carousel = block.bannerCarousel;
  final productList = block.productList;
  final categoryGrid = block.categoryGrid;
  final brandStrip = block.brandStrip;

  if (carousel != null) {
    // render carousel.banners
  } else if (productList != null) {
    // render productList.products
    if (productList.seeAll) {
      final nextPage = await client.listHomeProducts(
        listId: block.id,
        filter: selectedFilter == 'all' ? null : selectedFilter,
      );
    }
  } else if (categoryGrid != null) {
    // render categoryGrid.categories
  } else if (brandStrip != null) {
    // render brandStrip.brands
  }
}
```

Unknown block types stay available as `block.type` and `block.data`; skip them silently. Banners are managed in backend `Mobile Home Banner` records. Product images are resolved from `Product.image` first, then the first public `File` attachment on the Product. Home chip keys can also be passed to `listHomeProducts(filter: ...)` or `listProducts(filter: ...)`; use `null` for the `all` chip.

## Request IDs

Pass a `requestIdProvider` if the app wants to trace requests through backend logs. The SDK sends it as `X-Request-Id`.

```dart
final client = AlkokhMobileClient(
  config: sdkConfig,
  tokenStore: tokenStore,
);
```

## Auth Flow

```dart
await client.signIn(
  phone: '07700000001',
  password: 'Mobile@1234',
);

final me = await client.getMe();
```

The SDK stores sessions through the provided `TokenStore`, refreshes access tokens when needed, and clears stored sessions after password change, phone verification, sign-out, or account delete.

## Pet Breeds

Use the backend breed master for pet forms:

```dart
final breeds = await client.listPetBreeds(
  animalType: 'Cat',
  animalSpecies: 'Mammal',
  search: 'domestic',
);
```

## Appointments

Load booking types from the backend instead of hardcoding them:

```dart
final appointmentTypes = await client.listAppointmentTypes();
final selectedType = appointmentTypes.first.value; // e.g. visit

final slots = await client.getAvailableAppointmentSlots(
  date: DateTime.now().add(const Duration(days: 1)),
);

final appointment = await client.bookAppointment(
  petId: pet.id,
  scheduledTime: DateTime.parse(slots.first.start),
  appointmentType: selectedType,
);
```

## Uploads With Progress

Avatar and pet photos use multipart upload and backend `File` records.

```dart
await client.uploadAvatar(
  bytes: imageBytes,
  filename: 'avatar.jpg',
  onProgress: (sent, total) {
    final progress = sent / total;
  },
);

await client.uploadPetPhoto(
  petId,
  bytes: imageBytes,
  filename: 'pet.jpg',
  onProgress: (sent, total) {},
);
```

## Cash-Only Orders

Checkout remains cash-only and creates ERPNext `Sales Order` records.

```dart
final quote = await client.quoteOrder(
  items: const [MobileOrderItem(itemCode: 'ITEM-001', qty: 1)],
);

if (quote.canPlaceOrder) {
  final order = await client.placeOrder(
    items: const [MobileOrderItem(itemCode: 'ITEM-001', qty: 1)],
  );
}
```

## Smoke Test

Run a quick real-server check from this package:

```bash
dart run tool/smoke_test.dart
```

Optional environment variables:

```bash
ALKOKH_BASE_URL=http://178.105.22.175:8002 \
ALKOKH_PHONE=07700000001 \
ALKOKH_PASSWORD=Mobile@1234 \
ALKOKH_SMOKE_QUOTE_ITEM=ITEM-001 \
dart run tool/smoke_test.dart
```
