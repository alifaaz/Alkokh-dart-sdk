# Mobile Team Update: Home And Banners

This SDK update makes `client.getHome()` the single Home API in the SDK. It returns the block-based Home response with backend-managed banners.

## What Changed

New SDK methods:

```dart
final home = await client.getHome();
final page = await client.listHomeProducts(listId: 'best-sellers');
final dogPage = await client.listHomeProducts(
  listId: 'best-sellers',
  filter: 'dog',
);
```

New typed models:

```dart
MobileHome
HomeFilter
HomeBlock
HomeBanner
HomeAction
HomeProductCard
HomeCategoryCard
HomeBrand
```

Supported Home block types:

```text
banner_carousel
single_banner
product_list
category_grid
brand_strip
```

Unknown block types should be skipped silently.

## SDK Update Required

Update the SDK dependency in the Flutter app.

If using GitHub:

```yaml
dependencies:
  alkokh_mobile_sdk:
    git:
      url: https://github.com/alifaaz/Alkokh-dart-sdk.git
      ref: master
```

Then run:

```bash
flutter pub upgrade alkokh_mobile_sdk
```

## Home Usage

Use this for the mobile home screen:

```dart
final home = await client.getHome();

for (final block in home.blocks) {
  final carousel = block.bannerCarousel;
  final singleBanner = block.singleBanner;
  final productList = block.productList;
  final categoryGrid = block.categoryGrid;
  final brandStrip = block.brandStrip;

  if (carousel != null) {
    // render carousel.banners
  } else if (singleBanner != null) {
    // render singleBanner.banner
  } else if (productList != null) {
    // render productList.products
  } else if (categoryGrid != null) {
    // render categoryGrid.categories
  } else if (brandStrip != null) {
    // render brandStrip.brands
  }
}
```

## See-All Product Lists

If a `product_list` block has:

```dart
productList.seeAll == true
```

Load more products with:

```dart
final page = await client.listHomeProducts(
  listId: block.id,
  filter: selectedFilter == 'all' ? null : selectedFilter,
  limit: 20,
  cursor: nextCursor,
);
```

Currently supported list ids:

```text
best-sellers
recently-added
back-in-stock
```

## Banner Actions

Banner actions have:

```dart
banner.action.type
banner.action.value
```

Supported action types:

```text
product
category
brand
list
url
```

Suggested handling:

| Action Type | Behavior |
|---|---|
| `product` | Open product detail using `value` as product id. |
| `category` | Open product list filtered by category id. |
| `brand` | Open product list filtered by brand id. |
| `list` | Open Home see-all list using `listHomeProducts(listId: value)`. |
| `url` | Open external/in-app browser. |

## Product Card Notes

Home product cards include:

```dart
product.id
product.name
product.image
product.price
product.originalPrice
product.currency
product.unit
product.inStock
product.rating
product.ratingCount
product.filter
```

`product.filter` is one of:

```text
dog
cat
fish
bird
other
```

Use it for the Home chips. The key `all` is chip behavior only and is not sent as a product value.

For see-all/infinite-scroll pages, pass the selected chip to the SDK:

```dart
final page = await client.listHomeProducts(
  listId: block.id,
  filter: selectedFilter == 'all' ? null : selectedFilter,
  cursor: nextCursor,
);
```

The same filter is also available on the general catalog list:

```dart
final page = await client.listProducts(
  filter: 'cat',
  tag: 'recently-added',
);
```

`filter` is the species/chip key. `tag` matches exact comma-separated `Product.tags` values from the backend, such as `recently-added`, `best-seller`, or `back-in-stock`.

## Cache

`getHome()` uses the SDK safe public-read cache when `cacheEnabled: true`.

Use:

```dart
final freshHome = await client.getHome(forceRefresh: true);
```

to bypass cache.

## Important Notes

- `getHome()` is the only Home method exposed by the SDK.
- No favorite/cart/user-specific state is included in Home.
- Banners are managed by backend/admin through `Mobile Home Banner`.
- Product images come from backend Product image data.
- Unknown blocks should be skipped, not treated as errors.
