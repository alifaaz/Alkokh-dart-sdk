# Changelog

## Unreleased

**Breaking — `area` replaces `county` as the address API key (SDK 0.2.0).** Send `area`, read `area`. Sending `county` is now refused with `HTTP 400 address.request_invalid`, message `'county' is no longer accepted. Send 'area' instead.` — on create and update, whether or not other fields are present. It fails rather than losing the value, so an app on the old build errors on save until it updates. The stored column is unchanged; existing data is intact.

### Your four questions

1. **The field is saved.** It was always writable — the contract's field list was wrong. It is now called `area` (see above).
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

### Things to code around

**`display` omits the area.** It is ERPNext's rendered address and the Iraq template skips that field. An address in Karrada comes back as:

```
House 12, St 4<br>Baghdad<br>Iraq
```

Build the Area line from `MobileAddress.area`.

**`profile.me` doesn't carry it.** The default-address summary embedded in the profile is a narrower shape — `address_line1`, `address_line2`, `city`, `country`, `is_primary_address`, `notes` — with no `area` and no coordinates. Use the address endpoints when you need the full record.

**`registerDevice` stores FCM tokens that nothing reads.** There is no FCM sender in the backend — push runs on OneSignal against a different record. `getConfig()` reports `push_notifications: true` because that flag tracks the OneSignal path, so a successful `registerDevice` does not mean push is wired up. Talk to the backend before building on it.

### `listHomeProducts`

Now resolves custom home blocks through `catalog.home_block_v2`, falling back to the old endpoint for the three system lists. Source-compatible; new optional `locale`. `tag` still routes to the old endpoint.

Custom blocks need a published home layout, and nothing is published on the backend yet — "Show All" on an admin-created list will keep failing until one is.

### Also

`setDefault` returns the full address payload, so you can drop it straight into your list state. It clears the flag on every sibling, so refresh the rest. A soft-deleted address returns **404**, not 400.

No breaking changes. 44 tests passing, `dart analyze` clean.
