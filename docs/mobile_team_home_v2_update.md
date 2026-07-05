# Mobile Team Update: Home V2 And Banners

This SDK update adds support for the new block-based mobile Home v2 response and backend-managed banners.

## What Changed

New SDK methods:

```dart
final home = await client.getHomeV2();
final page = await client.listHomeProducts(listId: 'best-sellers');
```

New typed models:

```dart
HomeV2
HomeFilter
HomeBlock
HomeBanner
HomeAction
HomeProductCard
HomeCategoryCard
HomeBrand
```

New supported Home v2 block types:

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

## New Home Usage

Use this instead of the old `getHome()` for the mobile home screen:

```dart
final home = await client.getHomeV2();

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

Home v2 product cards include:

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

## Cache

`getHomeV2()` uses the SDK safe public-read cache when `cacheEnabled: true`.

Use:

```dart
final freshHome = await client.getHomeV2(forceRefresh: true);
```

to bypass cache.

## Important Notes

- `getHome()` still exists for old code, but the new mobile home screen should use `getHomeV2()`.
- No favorite/cart/user-specific state is included in Home v2.
- Banners are managed by backend/admin through `Mobile Home Banner`.
- Product images come from backend Product image data.
- Unknown blocks should be skipped, not treated as errors.

