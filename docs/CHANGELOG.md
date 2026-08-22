# Changelog

## Unreleased

### Your four questions

1. **`county` is saved.** Keep sending it — it was always writable. The contract's field list was wrong.
2. **`address`, `address_id` and `id` all work** on get, update, setDefault and delete. No change needed.
3. **Addresses refuse with HTTP 400 and an `error` key**, so your app was never showing "Address saved" on a rejected save.
4. **But you were right about `book_appointment`** — it refused with HTTP 200 and the SDK returned an empty `MobileAppointment`. Fixed: it now throws `AlkokhMobileException` carrying the server's message.

### New on addresses — live on the backend now

`notes`, `latitude`, `longitude` on `createAddress` and `updateAddress`; `clearCoordinates` on `updateAddress`. All three parse onto `MobileAddress`.

`notes` is the delivery instruction ("gate code 4471"). It never appears on printed documents.

Coordinates go together. The SDK throws `AlkokhValidationException` before sending:

| You send | Result |
|---|---|
| Neither | Pin untouched — safe to update other fields alone |
| Both, valid | Stored (±90 / ±180, ~0.1 m accuracy) |
| `clearCoordinates: true` | Both cleared |
| One only | Refused |
| One valued, one blank | Refused |

**`(0, 0)` reads back as `null`.** Unset and zero are indistinguishable on the backend, so it reports both as null. `latitude` and `longitude` are always null together. Don't use `(0, 0)` in a test fixture — it will look like a bug.

### Two things to code around

**`display` omits `county`.** It is ERPNext's rendered address and the Iraq template skips the field. An address in Karrada comes back as:

```
House 12, St 4<br>Baghdad<br>Iraq
```

Build the Area line from `MobileAddress.county`. (The admin UI now labels the field "Area"; the name on the wire stays `county`.)

**`registerDevice` stores FCM tokens that nothing reads.** There is no FCM sender in the backend — push runs on OneSignal against a different record. `getConfig()` reports `push_notifications: true` because that flag tracks the OneSignal path, so a successful `registerDevice` does not mean push is wired up. Talk to the backend before building on it.

### `listHomeProducts`

Now resolves custom home blocks through `catalog.home_block_v2`, falling back to the old endpoint for the three system lists. Source-compatible; new optional `locale`. `tag` still routes to the old endpoint.

Custom blocks need a published home layout, and nothing is published on the backend yet — "Show All" on an admin-created list will keep failing until one is.

### Also

`setDefault` returns the full address payload, so you can drop it straight into your list state. It clears the flag on every sibling, so refresh the rest. A soft-deleted address returns **404**, not 400.

No breaking changes. 44 tests passing, `dart analyze` clean.
