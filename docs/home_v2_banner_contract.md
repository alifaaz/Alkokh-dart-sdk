# Home V2 Banner JSON Contract

Use this contract for rendering banners from the mobile Home v2 endpoint.

## Endpoint

The SDK method is:

```dart
final home = await client.getHomeV2();
```

Raw backend method:

```text
GET /api/method/pet_app.api.mobile.catalog.home_v2
```

The response is wrapped by Frappe:

```json
{
  "message": {
    "ok": true,
    "data": {
      "version": 2,
      "updated_at": "2026-07-05T12:00:00Z",
      "cache_ttl_seconds": 300,
      "locale": "en",
      "filters": [],
      "blocks": []
    }
  }
}
```

Frontend should use `message.data`.

## Banner Block Types

Home v2 can return two banner block types:

```text
banner_carousel
single_banner
```

Every block has the same envelope:

```json
{
  "id": "stable-block-id",
  "type": "banner_carousel",
  "data": {}
}
```

Unknown block types should be skipped silently.

## Banner Carousel

Use this for a horizontal/auto carousel.

```json
{
  "id": "hero-banners",
  "type": "banner_carousel",
  "data": {
    "banners": [
      {
        "id": "summer-sale",
        "image": "https://api.example.com/files/summer-sale.png",
        "title": "Summer Sale",
        "subtitle": "Up to 30% off dog essentials",
        "button_title": "Shop Now",
        "gradient": ["#FF9A56", "#FF5E62"],
        "action": {
          "type": "category",
          "value": "dog-food"
        }
      }
    ]
  }
}
```

## Single Banner

Use this for a full-width single promo banner.

```json
{
  "id": "mid-feed-promo",
  "type": "single_banner",
  "data": {
    "banner": {
      "id": "grooming-week",
      "image": "https://api.example.com/files/grooming-week.png",
      "title": "Grooming Week",
      "subtitle": "Buy 2 get 1 free on shampoos",
      "button_title": "See Deals",
      "gradient": ["#A18CD1", "#FBC2EB"],
      "action": {
        "type": "category",
        "value": "grooming"
      }
    }
  }
}
```

## Banner Object

```json
{
  "id": "summer-sale",
  "image": "https://api.example.com/files/summer-sale.png",
  "title": "Summer Sale",
  "subtitle": "Up to 30% off dog essentials",
  "button_title": "Shop Now",
  "gradient": ["#FF9A56", "#FF5E62"],
  "action": {
    "type": "category",
    "value": "dog-food"
  }
}
```

| Field | Type | Required | Notes |
|---|---|---:|---|
| `id` | string | yes | Stable banner id for analytics/click handling. |
| `image` | string | yes | Absolute public URL. Frontend should treat empty/missing as invalid and skip banner. |
| `title` | string | yes | Display title. Can be empty but will always be present. |
| `subtitle` | string | yes | Display subtitle. Can be empty but will always be present. |
| `button_title` | string | yes | CTA text. |
| `gradient` | string array | yes | Two `#RRGGBB` colors. Use as overlay/background fallback. |
| `action` | object | yes | CTA/deep-link action. |

## Action Object

```json
{
  "type": "list",
  "value": "best-sellers"
}
```

Supported action types:

| Type | Value Means | Frontend Behavior |
|---|---|---|
| `product` | Product id | Open product detail. |
| `category` | Product Category id | Open product list filtered by category. |
| `brand` | Brand id | Open product list filtered by brand. |
| `list` | Home/list id | Open see-all list, e.g. `best-sellers`. |
| `url` | Absolute URL | Open external/in-app browser. |

## See-All List Values

For banner actions with:

```json
{ "type": "list", "value": "best-sellers" }
```

Use:

```dart
final page = await client.listHomeProducts(listId: 'best-sellers');
```

Supported list ids:

```text
best-sellers
recently-added
back-in-stock
```

## Frontend Rules

- Skip unknown block types.
- Skip a banner if `image` is empty.
- Skip a banner if `action.type` or `action.value` is empty.
- Do not expect favorite/cart/user state in Home v2.
- Cache Home v2 using `updated_at` and `cache_ttl_seconds`.
- Banner images come from backend `Mobile Home Banner` records.

