# Alkokh Mobile SDK Usage

The SDK talks to Frappe method endpoints internally. The Flutter app should use SDK methods directly and should not build `/v1/...` REST paths.

## Install

Install from GitHub in the Flutter app:

```yaml
dependencies:
  alkokh_mobile_sdk:
    git:
      url: https://github.com/alifaaz/Alkokh-dart-sdk.git
      ref: main
```

For local development, the Flutter app can temporarily use `path: ../packages/alkokh_mobile_sdk`.

## External App Config

Keep backend values in the Flutter app configuration layer, then pass them into the SDK:

```dart
final sdkConfig = AlkokhMobileConfig(
  baseUrl: appConfig.apiBaseUrl,
  requestIdProvider: () => appConfig.nextRequestId(),
);
```

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
