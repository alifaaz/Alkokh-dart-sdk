import 'dart:convert';

import 'package:alkokh_mobile_sdk/alkokh_mobile_sdk.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  test('signIn unwraps Frappe message and stores session', () async {
    final store = MemoryTokenStore();
    final client = AlkokhMobileClient(
      config: const AlkokhMobileConfig(baseUrl: 'https://api.example.test'),
      httpClient: MockClient((request) async {
        expect(request.url.origin, 'https://api.example.test');
        expect(request.url.path, '/api/method/pet_app.api.mobile.auth.sign_in');
        expect(jsonDecode(request.body), {
          'phone': '07700000001',
          'password': 'Mobile@1234',
        });
        return _json({
          'message': {
            'ok': true,
            'data': {
              'access_token': 'access',
              'refresh_token': 'refresh',
              'expires_in': 3600,
              'token_type': 'Bearer',
              'user': 'test@example.com',
              'full_name': 'Test User',
            },
          },
        });
      }),
      tokenStore: store,
    );

    final session = await client.signIn(
      phone: '07700000001',
      password: 'Mobile@1234',
    );

    expect(session.accessToken, 'access');
    expect((await store.read())?.refreshToken, 'refresh');
  });

  test(
    'refresh keeps existing refresh token when backend returns null',
    () async {
      final store = MemoryTokenStore();
      await store.write(
        AuthSession(
          accessToken: 'old-access',
          refreshToken: 'old-refresh',
          expiresIn: 3600,
          tokenType: 'Bearer',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        ),
      );

      final client = AlkokhMobileClient(
        httpClient: MockClient((request) async {
          return _json({
            'message': {
              'ok': true,
              'data': {
                'access_token': 'new-access',
                'refresh_token': null,
                'expires_in': 3600,
                'token_type': 'Bearer',
              },
            },
          });
        }),
        tokenStore: store,
      );

      final session = await client.refresh();

      expect(session.accessToken, 'new-access');
      expect(session.refreshToken, 'old-refresh');
      expect((await store.read())?.refreshToken, 'old-refresh');
    },
  );

  test('KeyValueTokenStore persists session JSON behind callbacks', () async {
    final storage = <String, String>{};
    final store = KeyValueTokenStore(
      readValue: (key) async => storage[key],
      writeValue: (key, value) async {
        storage[key] = value;
      },
      deleteValue: (key) async {
        storage.remove(key);
      },
    );

    await store.write(
      AuthSession(
        accessToken: 'access',
        refreshToken: 'refresh',
        expiresIn: 3600,
        tokenType: 'Bearer',
        expiresAt: DateTime.parse('2026-06-29T10:00:00Z'),
        user: 'test@example.com',
      ),
    );

    expect(storage, contains('alkokh_mobile_session'));
    expect((await store.read())?.accessToken, 'access');

    await store.clear();
    expect(await store.read(), isNull);
  });

  test('KeyValueCacheStore persists cache JSON behind callbacks', () async {
    final storage = <String, String>{};
    final store = KeyValueCacheStore(
      readValue: (key) async => storage[key],
      writeValue: (key, value) async {
        storage[key] = value;
      },
      deleteValue: (key) async {
        storage.remove(key);
      },
    );

    await store.write(
      'products?limit=20',
      CacheEntry(
        data: {
          'items': [
            {'id': 'Product-001'},
          ],
        },
        createdAt: DateTime.parse('2026-06-29T10:00:00Z'),
      ),
    );

    expect(storage, contains('alkokh_mobile_cache:index'));
    expect((await store.read('products?limit=20'))?.data['items'], isA<List>());

    await store.deleteWhere((key) => key.startsWith('products?'));
    expect(await store.read('products?limit=20'), isNull);
  });

  test('config builds URL from scheme host and port', () async {
    final client = AlkokhMobileClient(
      config: const AlkokhMobileConfig(
        scheme: 'https',
        host: 'api.example.test',
        port: 9443,
      ),
      httpClient: MockClient((request) async {
        expect(request.url.origin, 'https://api.example.test:9443');
        expect(
          request.url.path,
          '/api/method/pet_app.api.mobile.config.get_config',
        );
        return _configResponse(currency: 'IQD');
      }),
    );

    expect((await client.getConfig()).currency, 'IQD');
  });

  test('baseUrl takes precedence over structured URL config', () async {
    final client = AlkokhMobileClient(
      config: const AlkokhMobileConfig(
        baseUrl: 'https://base.example.test',
        scheme: 'http',
        host: 'ignored.example.test',
        port: 8002,
      ),
      httpClient: MockClient((request) async {
        expect(request.url.origin, 'https://base.example.test');
        return _configResponse(currency: 'IQD');
      }),
    );

    expect((await client.getConfig()).currency, 'IQD');
  });

  test('cache disabled calls safe public reads every time', () async {
    var call = 0;
    final client = AlkokhMobileClient(
      config: const AlkokhMobileConfig(cacheEnabled: false),
      httpClient: MockClient((request) async {
        call++;
        return _configResponse(currency: 'IQD');
      }),
    );

    await client.getConfig();
    await client.getConfig();

    expect(call, 2);
  });

  test('cache enabled caches product pages by cursor query', () async {
    var call = 0;
    final client = AlkokhMobileClient(
      config: const AlkokhMobileConfig(cacheEnabled: true),
      httpClient: MockClient((request) async {
        call++;
        return _json({
          'message': {
            'ok': true,
            'data': {
              'items': [
                {
                  'id': 'Product-${call.toString().padLeft(3, '0')}',
                  'name': 'Product $call',
                  'effective_price': 1000,
                  'in_stock': true,
                },
              ],
              'hasMore': false,
            },
          },
        });
      }),
    );

    final first = await client.listProducts(limit: 20);
    final firstAgain = await client.listProducts(limit: 20);
    final secondCursor = await client.listProducts(limit: 20, cursor: '20');

    expect(first.items.single.id, 'Product-001');
    expect(firstAgain.items.single.id, 'Product-001');
    expect(secondCursor.items.single.id, 'Product-002');
    expect(call, 2);
  });

  test(
    'forceRefresh bypasses cache and overwrites cached safe reads',
    () async {
      var call = 0;
      final client = AlkokhMobileClient(
        config: const AlkokhMobileConfig(cacheEnabled: true),
        httpClient: MockClient((request) async {
          call++;
          return _configResponse(currency: call == 1 ? 'IQD' : 'USD');
        }),
      );

      expect((await client.getConfig()).currency, 'IQD');
      expect((await client.getConfig(forceRefresh: true)).currency, 'USD');
      expect((await client.getConfig()).currency, 'USD');
      expect(call, 2);
    },
  );

  test('expired cache refetches safe public reads', () async {
    var call = 0;
    final client = AlkokhMobileClient(
      config: const AlkokhMobileConfig(
        cacheEnabled: true,
        cacheTtl: Duration.zero,
      ),
      httpClient: MockClient((request) async {
        call++;
        return _configResponse(currency: call == 1 ? 'IQD' : 'USD');
      }),
    );

    expect((await client.getConfig()).currency, 'IQD');
    expect((await client.getConfig()).currency, 'USD');
    expect(call, 2);
  });

  test(
    'staleOnError returns stale cached safe read on network failure',
    () async {
      var call = 0;
      final client = AlkokhMobileClient(
        config: const AlkokhMobileConfig(cacheEnabled: true),
        httpClient: MockClient((request) async {
          call++;
          if (call == 1) {
            return _configResponse(currency: 'IQD');
          }
          throw Exception('offline');
        }),
      );

      expect((await client.getConfig()).currency, 'IQD');
      expect((await client.getConfig(forceRefresh: true)).currency, 'IQD');
      expect(call, 2);
    },
  );

  test('private reads are not cached by default', () async {
    final store = await _authedStore();
    var call = 0;
    final client = AlkokhMobileClient(
      config: const AlkokhMobileConfig(cacheEnabled: true),
      httpClient: MockClient((request) async {
        call++;
        expect(request.headers['Authorization'], 'Bearer access');
        return _json({
          'message': {
            'ok': true,
            'data': {'guardian_id': 'G-$call'},
          },
        });
      }),
      tokenStore: store,
    );

    expect((await client.getMe()).guardianId, 'G-1');
    expect((await client.getMe()).guardianId, 'G-2');
    expect(call, 2);
  });

  test('listOrders sends Bearer token and parses paged orders', () async {
    final store = MemoryTokenStore();
    await store.write(
      AuthSession(
        accessToken: 'access',
        refreshToken: 'refresh',
        expiresIn: 3600,
        tokenType: 'Bearer',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      ),
    );

    final client = AlkokhMobileClient(
      httpClient: MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer access');
        expect(
          request.url.path,
          '/api/method/pet_app.api.mobile.orders.list_orders',
        );
        return _json({
          'message': {
            'ok': true,
            'data': {
              'items': [
                {
                  'id': 'SAL-ORD-0001',
                  'status': 'Draft',
                  'status_key': 'draft',
                  'grand_total': 12000,
                },
              ],
              'nextCursor': null,
              'hasMore': false,
            },
          },
        });
      }),
      tokenStore: store,
    );

    final page = await client.listOrders();

    expect(page.hasMore, isFalse);
    expect(page.items.single.id, 'SAL-ORD-0001');
    expect(page.items.single.grandTotal, 12000);
  });

  test('getConfig parses public mobile config', () async {
    final client = AlkokhMobileClient(
      httpClient: MockClient((request) async {
        expect(
          request.url.path,
          '/api/method/pet_app.api.mobile.config.get_config',
        );
        expect(request.headers.containsKey('Authorization'), isFalse);
        return _json({
          'message': {
            'ok': true,
            'data': {
              'currency': 'IQD',
              'supported_locales': ['en', 'ar'],
              'default_locale': 'en',
              'feature_flags': {'catalog': true, 'cart': false},
            },
          },
        });
      }),
    );

    final config = await client.getConfig();

    expect(config.currency, 'IQD');
    expect(config.supportedLocales, ['en', 'ar']);
    expect(config.featureFlags['catalog'], isTrue);
    expect(config.featureFlags['cart'], isFalse);
  });

  test('listProducts parses catalog product page', () async {
    final client = AlkokhMobileClient(
      httpClient: MockClient((request) async {
        expect(
          request.url.path,
          '/api/method/pet_app.api.mobile.catalog.list_products',
        );
        expect(request.url.queryParameters['limit'], '20');
        expect(request.url.queryParameters['filter'], 'dog');
        expect(request.url.queryParameters['tag'], 'best-seller');
        return _json({
          'message': {
            'ok': true,
            'data': {
              'items': [
                {
                  'id': 'Product-001',
                  'name': 'Cat Food',
                  'effective_price': 15000,
                  'in_stock': true,
                  'category': {'id': 'Food', 'name': 'Food'},
                  'brand': {'id': 'Brand', 'name': 'Brand'},
                },
              ],
              'hasMore': false,
              'nextCursor': null,
            },
          },
        });
      }),
    );

    final page = await client.listProducts(filter: 'dog', tag: 'best-seller');

    expect(page.items.single.id, 'Product-001');
    expect(page.items.single.category?.name, 'Food');
    expect(page.items.single.brand?.name, 'Brand');
  });

  test('getHome and listHomeProducts parse block contract', () async {
    var call = 0;
    final client = AlkokhMobileClient(
      httpClient: MockClient((request) async {
        switch (call++) {
          case 0:
            expect(
              request.url.path,
              '/api/method/pet_app.api.mobile.catalog.home_v2',
            );
            expect(request.url.queryParameters['lang'], 'en');
            return _json({
              'message': {
                'ok': true,
                'data': {
                  'version': 2,
                  'updated_at': '2026-07-02T18:30:00Z',
                  'cache_ttl_seconds': 300,
                  'locale': 'en',
                  'filters': [
                    {'key': 'all', 'label': 'All'},
                    {'key': 'dog', 'label': 'Dog'},
                  ],
                  'blocks': [
                    {
                      'id': 'hero-banners',
                      'type': 'banner_carousel',
                      'data': {
                        'banners': [
                          {
                            'id': 'summer',
                            'image': 'https://cdn.example.test/banner.png',
                            'title': 'Summer',
                            'subtitle': 'Deals',
                            'button_title': 'Shop',
                            'gradient': ['#FF9A56', '#FF5E62'],
                            'action': {'type': 'list', 'value': 'best-sellers'},
                          },
                        ],
                      },
                    },
                    {
                      'id': 'best-sellers',
                      'type': 'product_list',
                      'data': {
                        'title': 'Best Sellers',
                        'see_all': true,
                        'respects_filter': true,
                        'products': [
                          {
                            'id': 'PROD-1',
                            'name': 'Dog Food',
                            'image': 'https://cdn.example.test/prod.png',
                            'price': 24000,
                            'original_price': 30000,
                            'currency': 'IQD',
                            'unit': '2 kg',
                            'in_stock': true,
                            'rating': 4.6,
                            'rating_count': 41,
                            'filter': 'dog',
                          },
                        ],
                      },
                    },
                    {
                      'id': 'future',
                      'type': 'future_block',
                      'data': {'kept': true},
                    },
                  ],
                },
              },
            });
          case 1:
            expect(
              request.url.path,
              '/api/method/pet_app.api.mobile.catalog.list_products',
            );
            expect(request.url.queryParameters['list'], 'best-sellers');
            expect(request.url.queryParameters['filter'], 'cat');
            expect(request.url.queryParameters['tag'], 'recently-added');
            expect(request.url.queryParameters['cursor'], '20');
            return _json({
              'message': {
                'ok': true,
                'data': {
                  'items': [
                    {
                      'id': 'PROD-2',
                      'name': 'Cat Food',
                      'image': 'https://cdn.example.test/cat.png',
                      'price': 30000,
                      'effective_price': 25000,
                      'original_price': 30000,
                      'currency': 'IQD',
                      'unit': '1 kg',
                      'in_stock': true,
                      'rating': 4.2,
                      'rating_count': 10,
                      'filter': 'cat',
                    },
                  ],
                  'hasMore': false,
                  'nextCursor': null,
                },
              },
            });
        }
        fail('Unexpected request ${request.url.path}');
      }),
    );

    final home = await client.getHome(lang: 'en');
    expect(home.version, 2);
    expect(home.filters.first.key, 'all');
    expect(
      home.blocks.first.bannerCarousel?.banners.single.action.value,
      'best-sellers',
    );
    expect(home.blocks[1].productList?.products.single.originalPrice, 30000);
    expect(home.blocks[2].isKnown, isFalse);

    final page = await client.listHomeProducts(
      listId: 'best-sellers',
      filter: 'cat',
      tag: 'recently-added',
      cursor: '20',
    );
    expect(page.items.single.price, 25000);
    expect(page.items.single.filter, 'cat');
    expect(call, 2);
  });

  test('getMe sends Bearer token and parses profile', () async {
    final store = MemoryTokenStore();
    await store.write(
      AuthSession(
        accessToken: 'access',
        refreshToken: 'refresh',
        expiresIn: 3600,
        tokenType: 'Bearer',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      ),
    );

    final client = AlkokhMobileClient(
      httpClient: MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer access');
        expect(request.url.path, '/api/method/pet_app.api.mobile.profile.me');
        return _json({
          'message': {
            'ok': true,
            'data': {
              'user': '07700000001@petapp.local',
              'guardian_id': 'Guardian-001',
              'customer_id': 'Customer-001',
              'full_name': 'Mobile User',
              'phone': '07700000001',
            },
          },
        });
      }),
      tokenStore: store,
    );

    final profile = await client.getMe();

    expect(profile.guardianId, 'Guardian-001');
    expect(profile.fullName, 'Mobile User');
  });

  test('createAddress sends delivery address payload', () async {
    final store = MemoryTokenStore();
    await store.write(
      AuthSession(
        accessToken: 'access',
        refreshToken: 'refresh',
        expiresIn: 3600,
        tokenType: 'Bearer',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      ),
    );

    final client = AlkokhMobileClient(
      httpClient: MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer access');
        expect(
          request.url.path,
          '/api/method/pet_app.api.mobile.addresses.create_address',
        );
        expect(jsonDecode(request.body), {
          'title': 'Home',
          'address_line1': 'Street 1',
          'city': 'Baghdad',
          'country': 'Iraq',
          'is_default': 1,
        });
        return _json({
          'message': {
            'ok': true,
            'data': {
              'id': 'ADDRESS-0001',
              'title': 'Home',
              'address_line1': 'Street 1',
              'city': 'Baghdad',
              'country': 'Iraq',
              'is_default': true,
              'is_disabled': false,
            },
          },
        });
      }),
      tokenStore: store,
    );

    final address = await client.createAddress(
      title: 'Home',
      addressLine1: 'Street 1',
      city: 'Baghdad',
      country: 'Iraq',
      isDefault: true,
    );

    expect(address.id, 'ADDRESS-0001');
    expect(address.isDefault, isTrue);
  });

  test('listSupportedCities parses public city DTOs', () async {
    final client = AlkokhMobileClient(
      httpClient: MockClient((request) async {
        expect(
          request.url.path,
          '/api/method/pet_app.api.mobile.addresses.cities',
        );
        expect(request.headers.containsKey('Authorization'), isFalse);
        return _json({
          'message': {
            'ok': true,
            'data': {
              'items': [
                {'id': 'baghdad', 'name': 'Baghdad', 'country': 'Iraq'},
              ],
            },
          },
        });
      }),
    );

    final cities = await client.listSupportedCities();

    expect(cities.single.id, 'baghdad');
    expect(cities.single.country, 'Iraq');
  });

  test('listPets sends Bearer token and parses pet page', () async {
    final store = MemoryTokenStore();
    await store.write(
      AuthSession(
        accessToken: 'access',
        refreshToken: 'refresh',
        expiresIn: 3600,
        tokenType: 'Bearer',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      ),
    );

    final client = AlkokhMobileClient(
      httpClient: MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer access');
        expect(
          request.url.path,
          '/api/method/pet_app.api.mobile.pets.list_pets',
        );
        return _json({
          'message': {
            'ok': true,
            'data': {
              'items': [
                {
                  'id': 'PET-001',
                  'name': 'Luna',
                  'species': 'Mammal',
                  'type': 'Cat',
                  'is_deceased': false,
                },
              ],
              'hasMore': false,
              'nextCursor': null,
            },
          },
        });
      }),
      tokenStore: store,
    );

    final page = await client.listPets();

    expect(page.items.single.id, 'PET-001');
    expect(page.items.single.name, 'Luna');
    expect(page.items.single.type, 'Cat');
  });

  test('createPet sends mobile pet payload and parses disabled flag', () async {
    final store = MemoryTokenStore();
    await store.write(
      AuthSession(
        accessToken: 'access',
        refreshToken: 'refresh',
        expiresIn: 3600,
        tokenType: 'Bearer',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      ),
    );

    final client = AlkokhMobileClient(
      httpClient: MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer access');
        expect(
          request.url.path,
          '/api/method/pet_app.api.mobile.pets.create_pet',
        );
        expect(jsonDecode(request.body), {
          'name': 'Luna',
          'species': 'Mammal',
          'type': 'Cat',
          'weight': 4.2,
        });
        return _json({
          'message': {
            'ok': true,
            'data': {
              'id': 'PET-001',
              'name': 'Luna',
              'species': 'Mammal',
              'type': 'Cat',
              'pet_status': 'Approved',
              'is_disabled': false,
            },
          },
        });
      }),
      tokenStore: store,
    );

    final pet = await client.createPet(
      name: 'Luna',
      species: 'Mammal',
      type: 'Cat',
      weight: 4.2,
    );

    expect(pet.id, 'PET-001');
    expect(pet.petStatus, 'Approved');
    expect(pet.isDisabled, isFalse);
  });

  test(
    'favorites reviews and recent search SDK methods use mobile endpoints',
    () async {
      final store = await _authedStore();
      var call = 0;
      final client = AlkokhMobileClient(
        httpClient: MockClient((request) async {
          if (request.url.path !=
              '/api/method/pet_app.api.mobile.reviews.list_product_reviews') {
            expect(request.headers['Authorization'], 'Bearer access');
          }
          switch (call++) {
            case 0:
              expect(
                request.url.path,
                '/api/method/pet_app.api.mobile.favorites.list_favorites',
              );
              return _json({
                'message': {
                  'ok': true,
                  'data': {
                    'items': [
                      {
                        'id': 'FAV-1',
                        'product_id': 'PROD-1',
                        'is_favorite': true,
                      },
                    ],
                    'hasMore': false,
                  },
                },
              });
            case 1:
              expect(
                request.url.path,
                '/api/method/pet_app.api.mobile.favorites.toggle_favorite',
              );
              expect(jsonDecode(request.body), {'product': 'PROD-1'});
              return _json({
                'message': {
                  'ok': true,
                  'data': {'product_id': 'PROD-1', 'is_favorite': false},
                },
              });
            case 2:
              expect(
                request.url.path,
                '/api/method/pet_app.api.mobile.favorites.remove_favorite',
              );
              return _json({
                'message': {
                  'ok': true,
                  'data': {'product_id': 'PROD-1', 'is_favorite': false},
                },
              });
            case 3:
              expect(
                request.url.path,
                '/api/method/pet_app.api.mobile.reviews.list_product_reviews',
              );
              expect(request.headers.containsKey('Authorization'), isFalse);
              return _json({
                'message': {
                  'ok': true,
                  'data': {
                    'items': [
                      {'id': 'RATING-1', 'rating': 5, 'notes': 'Good'},
                    ],
                    'summary': {'count': 1, 'average': 5},
                    'hasMore': false,
                  },
                },
              });
            case 4:
              expect(
                request.url.path,
                '/api/method/pet_app.api.mobile.reviews.upsert_product_review',
              );
              expect(jsonDecode(request.body), {
                'product': 'PROD-1',
                'rating': 4,
                'notes': 'Nice',
              });
              return _json({
                'message': {
                  'ok': true,
                  'data': {'id': 'RATING-1', 'rating': 4, 'notes': 'Nice'},
                },
              });
            case 5:
              expect(
                request.url.path,
                '/api/method/pet_app.api.mobile.search_history.list_recent',
              );
              return _json({
                'message': {
                  'ok': true,
                  'data': {
                    'items': [
                      {'id': 'S-1', 'query': 'cat', 'last_searched_at': 'now'},
                    ],
                  },
                },
              });
            case 6:
              expect(
                request.url.path,
                '/api/method/pet_app.api.mobile.search_history.save_recent',
              );
              expect(jsonDecode(request.body), {'q': 'cat food'});
              return _json({
                'message': {
                  'ok': true,
                  'data': {
                    'items': [
                      {'id': 'S-2', 'query': 'cat food'},
                    ],
                  },
                },
              });
            case 7:
              expect(
                request.url.path,
                '/api/method/pet_app.api.mobile.search_history.clear_recent',
              );
              return _json({
                'message': {
                  'ok': true,
                  'data': {'items': []},
                },
              });
          }
          fail('Unexpected request ${request.url.path}');
        }),
        tokenStore: store,
      );

      expect((await client.listFavorites()).items.single.productId, 'PROD-1');
      expect((await client.toggleFavorite('PROD-1')).isFavorite, isFalse);
      expect((await client.removeFavorite('PROD-1')).productId, 'PROD-1');
      expect((await client.listProductReviews('PROD-1')).summary.count, 1);
      expect(
        (await client.upsertProductReview(
          'PROD-1',
          rating: 4,
          notes: 'Nice',
        )).rating,
        4,
      );
      expect((await client.listRecentSearches()).single.query, 'cat');
      expect(
        (await client.saveRecentSearch('cat food')).single.query,
        'cat food',
      );
      expect(await client.clearRecentSearches(), isEmpty);
      expect(call, 8);
    },
  );

  test('profile device and multipart upload SDK methods are wired', () async {
    final store = await _authedStore();
    var call = 0;
    final client = AlkokhMobileClient(
      httpClient: MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer access');
        switch (call++) {
          case 0:
            expect(
              request.url.path,
              '/api/method/pet_app.api.mobile.devices.register_device',
            );
            expect(jsonDecode(request.body), {
              'fcm_token': 'fcm',
              'platform': 'android',
              'device_id': 'device-1',
            });
            return _json({
              'message': {
                'ok': true,
                'data': {
                  'id': 'DEV-1',
                  'fcm_token': 'fcm',
                  'platform': 'android',
                  'disabled': false,
                },
              },
            });
          case 1:
            expect(
              request.url.path,
              '/api/method/pet_app.api.mobile.devices.delete_device',
            );
            return _json({
              'message': {
                'ok': true,
                'data': {'fcm_token': 'fcm', 'disabled': true},
              },
            });
          case 2:
            expect(
              request.url.path,
              '/api/method/pet_app.api.mobile.profile.phone_change_start',
            );
            return _json({
              'message': {
                'ok': true,
                'data': {'message': 'OTP sent', 'new_phone': '07700000002'},
              },
            });
          case 3:
            expect(
              request.url.path,
              '/api/method/pet_app.api.mobile.profile.upload_avatar',
            );
            expect(
              request.headers['content-type'],
              contains('multipart/form-data'),
            );
            expect(latin1.decode(request.bodyBytes), contains('avatar.jpg'));
            return _json({
              'message': {
                'ok': true,
                'data': {
                  'file': {'id': 'FILE-1', 'file_url': '/files/avatar.jpg'},
                  'profile': {'guardian_id': 'G-1', 'full_name': 'Mobile User'},
                },
              },
            });
        }
        fail('Unexpected request ${request.url.path}');
      }),
      tokenStore: store,
    );

    expect(
      (await client.registerDevice(
        fcmToken: 'fcm',
        platform: 'android',
        deviceId: 'device-1',
      )).id,
      'DEV-1',
    );
    expect((await client.deleteDevice('fcm')).disabled, isTrue);
    expect(
      (await client.phoneChangeStart('07700000002')).newPhone,
      '07700000002',
    );
    expect(
      (await client.uploadAvatar(
        bytes: [1, 2, 3],
        filename: 'avatar.jpg',
      )).file.fileUrl,
      '/files/avatar.jpg',
    );
    expect(call, 4);
  });

  test(
    'password phone verify and account delete clear stored sessions',
    () async {
      var store = await _authedStore();
      var client = AlkokhMobileClient(
        httpClient: MockClient((request) async {
          expect(
            request.url.path,
            '/api/method/pet_app.api.mobile.profile.change_password',
          );
          return _json({
            'message': {'ok': true, 'data': {}},
          });
        }),
        tokenStore: store,
      );
      await client.changePassword(
        currentPassword: 'Mobile@1234',
        newPassword: 'Mobile@5678',
      );
      expect(await store.read(), isNull);

      store = await _authedStore();
      client = AlkokhMobileClient(
        httpClient: MockClient((request) async {
          expect(
            request.url.path,
            '/api/method/pet_app.api.mobile.profile.phone_change_verify',
          );
          return _json({
            'message': {
              'ok': true,
              'data': {
                'profile': {'phone': '07700000002'},
              },
            },
          });
        }),
        tokenStore: store,
      );
      expect(
        (await client.phoneChangeVerify(otp: '123456')).phone,
        '07700000002',
      );
      expect(await store.read(), isNull);

      store = await _authedStore();
      client = AlkokhMobileClient(
        httpClient: MockClient((request) async {
          expect(
            request.url.path,
            '/api/method/pet_app.api.mobile.profile.delete_account',
          );
          return _json({
            'message': {
              'ok': true,
              'data': {'deleted': true},
            },
          });
        }),
        tokenStore: store,
      );
      await client.deleteAccount();
      expect(await store.read(), isNull);
    },
  );

  test('pet photo and medical record SDK methods are wired', () async {
    final store = await _authedStore();
    var call = 0;
    final client = AlkokhMobileClient(
      httpClient: MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer access');
        switch (call++) {
          case 0:
            expect(
              request.url.path,
              '/api/method/pet_app.api.mobile.pets.upload_photo',
            );
            expect(
              request.headers['content-type'],
              contains('multipart/form-data'),
            );
            final body = latin1.decode(request.bodyBytes);
            expect(body, contains('pet'));
            expect(body, contains('PET-1'));
            expect(body, contains('pet.jpg'));
            return _json({
              'message': {
                'ok': true,
                'data': {
                  'file': {'id': 'FILE-1', 'file_url': '/files/pet.jpg'},
                  'pet': {'id': 'PET-1', 'name': 'Luna'},
                },
              },
            });
          case 1:
            expect(
              request.url.path,
              '/api/method/pet_app.api.mobile.pets.list_medical_records',
            );
            return _json({
              'message': {
                'ok': true,
                'data': {
                  'items': [
                    {'id': 'VAC-1', 'type': 'vaccination', 'summary': 'Rabies'},
                  ],
                  'hasMore': false,
                },
              },
            });
          case 2:
            expect(
              request.url.path,
              '/api/method/pet_app.api.mobile.pets.add_medical_record',
            );
            expect(jsonDecode(request.body), {
              'pet': 'PET-1',
              'record_type': 'vaccination',
              'vaccine_name': 'Rabies',
              'administered_on': '2026-06-29',
            });
            return _json({
              'message': {
                'ok': true,
                'data': {
                  'id': 'VAC-1',
                  'type': 'vaccination',
                  'summary': 'Rabies',
                },
              },
            });
          case 3:
            expect(
              request.url.path,
              '/api/method/pet_app.api.mobile.pets.update_medical_record',
            );
            expect(jsonDecode(request.body), {
              'pet': 'PET-1',
              'notes': 'Done',
              'record': 'VAC-1',
            });
            return _json({
              'message': {
                'ok': true,
                'data': {'id': 'VAC-1', 'type': 'vaccination', 'notes': 'Done'},
              },
            });
          case 4:
            expect(
              request.url.path,
              '/api/method/pet_app.api.mobile.pets.delete_medical_record',
            );
            expect(jsonDecode(request.body), {
              'pet': 'PET-1',
              'record': 'VAC-1',
            });
            return _json({
              'message': {
                'ok': true,
                'data': {'deleted': true},
              },
            });
        }
        fail('Unexpected request ${request.url.path}');
      }),
      tokenStore: store,
    );

    expect(
      (await client.uploadPetPhoto(
        'PET-1',
        bytes: [1, 2, 3],
        filename: 'pet.jpg',
      )).pet.id,
      'PET-1',
    );
    expect(
      (await client.listPetMedicalRecords('PET-1')).items.single.id,
      'VAC-1',
    );
    expect(
      (await client.addPetMedicalRecord(
        'PET-1',
        recordType: 'vaccination',
        vaccineName: 'Rabies',
        administeredOn: '2026-06-29',
      )).summary,
      'Rabies',
    );
    expect(
      (await client.updatePetMedicalRecord(
        'PET-1',
        'VAC-1',
        notes: 'Done',
      )).notes,
      'Done',
    );
    await client.deletePetMedicalRecord('PET-1', 'VAC-1');
    expect(call, 5);
  });

  test('request ids and upload progress are sent when configured', () async {
    final store = await _authedStore();
    final progressEvents = <List<int>>[];
    var call = 0;
    final client = AlkokhMobileClient(
      config: AlkokhMobileConfig(
        requestIdProvider: () => 'request-${call + 1}',
      ),
      httpClient: MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer access');
        switch (call++) {
          case 0:
            expect(request.headers['X-Request-Id'], 'request-1');
            expect(
              request.url.path,
              '/api/method/pet_app.api.mobile.profile.me',
            );
            return _json({
              'message': {
                'ok': true,
                'data': {'guardian_id': 'G-1'},
              },
            });
          case 1:
            expect(request.headers['X-Request-Id'], 'request-2');
            expect(
              request.url.path,
              '/api/method/pet_app.api.mobile.profile.upload_avatar',
            );
            expect(
              request.headers['content-type'],
              contains('multipart/form-data'),
            );
            expect(request.bodyBytes, isNotEmpty);
            return _json({
              'message': {
                'ok': true,
                'data': {
                  'file': {'id': 'FILE-1', 'file_url': '/files/avatar.jpg'},
                  'profile': {'guardian_id': 'G-1'},
                },
              },
            });
        }
        fail('Unexpected request ${request.url.path}');
      }),
      tokenStore: store,
    );

    await client.getMe();
    await client.uploadAvatar(
      bytes: List<int>.filled(70 * 1024, 1),
      filename: 'avatar.jpg',
      onProgress: (sent, total) => progressEvents.add([sent, total]),
    );

    expect(call, 2);
    expect(progressEvents, isNotEmpty);
    expect(progressEvents.last, [70 * 1024, 70 * 1024]);
  });

  test('quoteOrder sends frontend cart and parses issues', () async {
    final store = MemoryTokenStore();
    await store.write(
      AuthSession(
        accessToken: 'access',
        refreshToken: 'refresh',
        expiresIn: 3600,
        tokenType: 'Bearer',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      ),
    );

    final client = AlkokhMobileClient(
      httpClient: MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer access');
        expect(request.url.path, '/api/method/pet_app.api.mobile.orders.quote');
        expect(jsonDecode(request.body), {
          'items': [
            {'item_code': 'ITEM-001', 'qty': 2},
          ],
        });
        return _json({
          'message': {
            'ok': true,
            'data': {
              'payment_method': 'Cash on Delivery',
              'currency': 'IQD',
              'items': [
                {
                  'item_code': 'ITEM-001',
                  'qty': 2,
                  'rate': 5000,
                  'amount': 10000,
                  'available_qty': 1,
                },
              ],
              'issues': [
                {
                  'code': 'cart.stock_limit_reached',
                  'message': 'Only 1 unit is available',
                  'item_code': 'ITEM-001',
                },
              ],
              'can_place_order': false,
              'subtotal': 10000,
              'delivery_fee': 0,
              'discount_amount': 0,
              'grand_total': 10000,
            },
          },
        });
      }),
      tokenStore: store,
    );

    final quote = await client.quoteOrder(
      items: const [MobileOrderItem(itemCode: 'ITEM-001', qty: 2)],
    );

    expect(quote.paymentMethod, 'Cash on Delivery');
    expect(quote.canPlaceOrder, isFalse);
    expect(quote.items.single.availableQty, 1);
    expect(quote.issues.single.code, 'cart.stock_limit_reached');
  });

  test('placeOrder rejects non-cash payment methods in SDK', () async {
    final client = AlkokhMobileClient();

    expect(
      () => client.placeOrder(
        items: const [MobileOrderItem(itemCode: 'ITEM-001', qty: 1)],
        paymentMethod: 'card',
      ),
      throwsA(isA<AlkokhValidationException>()),
    );
  });

  test('getAvailableAppointmentSlots maps backend slots', () async {
    final store = await _authedStore();
    final client = AlkokhMobileClient(
      config: const AlkokhMobileConfig(baseUrl: 'https://api.example.test'),
      tokenStore: store,
      httpClient: MockClient((request) async {
        expect(
          request.url.path,
          '/api/method/pet_app.api.scheduling.get_available_slots',
        );
        expect(request.url.queryParameters['date'], '2026-07-24');
        expect(request.url.queryParameters['service_type'], 'Visit');
        expect(request.url.queryParameters['duration_minutes'], '30');
        expect(request.headers['Authorization'], 'Bearer access');
        return _json({
          'message': {
            'ok': true,
            'data': {
              'slots': [
                {
                  'start': '2026-07-24 09:00:00',
                  'end': '2026-07-24 09:30:00',
                  'doctor': 'DOC-001',
                  'doctor_name': 'Dr Sara',
                  'room': 'ROOM-1',
                },
              ],
            },
          },
        });
      }),
    );

    final slots = await client.getAvailableAppointmentSlots(
      date: DateTime(2026, 7, 24),
      durationMinutes: 30,
    );

    expect(slots, hasLength(1));
    expect(slots.single.start, '2026-07-24 09:00:00');
    expect(slots.single.doctorName, 'Dr Sara');
  });

  test('listUpcomingAppointments maps guardian portal appointments', () async {
    final store = await _authedStore();
    final client = AlkokhMobileClient(
      tokenStore: store,
      httpClient: MockClient((request) async {
        expect(
          request.url.path,
          '/api/method/pet_app.api.guardian_portal.get_upcoming_appointments',
        );
        expect(request.url.queryParameters['limit'], '5');
        return _json({
          'message': {
            'ok': true,
            'data': {
              'appointments': [
                {
                  'name': 'APPT-001',
                  'status': 'Open',
                  'scheduled_time': '2026-07-24 10:00:00',
                  'custom_pet': 'PET-001',
                  'pet_name': 'Loli',
                  'custom_guardian': 'GUARDIAN-001',
                  'guardian_name': 'Mostafa',
                  'custom_appointment_type': 'visit',
                },
              ],
            },
          },
        });
      }),
    );

    final appointments = await client.listUpcomingAppointments(limit: 5);

    expect(appointments.single.id, 'APPT-001');
    expect(appointments.single.pet, 'PET-001');
    expect(appointments.single.petName, 'Loli');
    expect(appointments.single.appointmentType, 'visit');
  });

  test(
    'listAppointments defaults to logged-in guardian portal endpoint',
    () async {
      final store = await _authedStore();
      final client = AlkokhMobileClient(
        tokenStore: store,
        httpClient: MockClient((request) async {
          expect(
            request.url.path,
            '/api/method/pet_app.api.guardian_portal.get_appointments',
          );
          expect(request.url.queryParameters['pet'], 'PET-001');
          expect(request.url.queryParameters['status'], 'Open');
          expect(request.url.queryParameters['future_only'], '1');
          expect(request.url.queryParameters['date_from'], '2026-07-24');
          return _json({
            'message': {
              'ok': true,
              'data': {
                'appointments': [
                  {
                    'name': 'APPT-002',
                    'status': 'Open',
                    'scheduled_time': '2026-07-24 12:00:00',
                    'custom_pet': 'PET-001',
                  },
                ],
              },
            },
          });
        }),
      );

      final appointments = await client.listAppointments(
        petId: 'PET-001',
        status: 'Open',
        futureOnly: true,
        dateFrom: DateTime(2026, 7, 24),
      );

      expect(appointments.single.id, 'APPT-002');
    },
  );

  test('listAppointments can call filtered scheduling endpoint', () async {
    final store = await _authedStore();
    final client = AlkokhMobileClient(
      tokenStore: store,
      httpClient: MockClient((request) async {
        expect(
          request.url.path,
          '/api/method/pet_app.api.scheduling.list_appointments',
        );
        expect(request.url.queryParameters['guardian'], 'GUARDIAN-001');
        expect(request.url.queryParameters['customer'], 'Customer-001');
        expect(request.url.queryParameters['pet'], 'PET-001');
        expect(request.url.queryParameters['limit'], '10');
        return _json({
          'message': {
            'ok': true,
            'data': {
              'appointments': [
                {
                  'name': 'APPT-003',
                  'status': 'Open',
                  'scheduled_time': '2026-07-25 12:00:00',
                  'custom_guardian': 'GUARDIAN-001',
                  'custom_customer': 'Customer-001',
                  'custom_pet': 'PET-001',
                },
              ],
            },
          },
        });
      }),
    );

    final appointments = await client.listAppointments(
      guardianId: 'GUARDIAN-001',
      customerId: 'Customer-001',
      petId: 'PET-001',
      limit: 10,
      currentUserOnly: false,
    );

    expect(appointments.single.guardian, 'GUARDIAN-001');
    expect(appointments.single.customer, 'Customer-001');
  });

  test('listPetCareServices maps guardian services with details', () async {
    final store = await _authedStore();
    final client = AlkokhMobileClient(
      tokenStore: store,
      httpClient: MockClient((request) async {
        expect(
          request.url.path,
          '/api/method/pet_app.api.guardian_portal.get_pet_care_services',
        );
        expect(request.url.queryParameters['pet'], 'PET-001');
        expect(request.url.queryParameters['status'], 'pending');
        expect(
          request.url.queryParameters['category'],
          'CategoryCareServices-0001',
        );
        expect(request.url.queryParameters['date_from'], '2026-07-01');
        expect(request.url.queryParameters['date_to'], '2026-07-31');
        return _json({
          'message': {
            'ok': true,
            'data': {
              'services': [
                {
                  'name': 'PetCareService-00001',
                  'service_id': 'PetCareService-00001',
                  'pet_service_name': 'Grooming',
                  'status': 'pending',
                  'pet_id': 'PET-001',
                  'pet_name': 'Loli',
                  'guardian_id': 'GUARDIAN-001',
                  'category': 'CategoryCareServices-0001',
                  'category_name': 'Pet care',
                  'care_service_id': 'CareService-00001',
                  'service_option': 'CSBO-00001',
                  'price': 25000,
                  'due_date': '2026-07-24',
                  'care_service': {
                    'name': 'CareService-00001',
                    'service_name': 'Grooming',
                    'arabic_name': 'العناية',
                    'default_price': 25000,
                    'description': 'Full grooming',
                  },
                  'category_details': {
                    'name': 'CategoryCareServices-0001',
                    'category_name': 'Pet care',
                    'arabic_name': 'رعاية الحيوانات',
                  },
                  'service_option_details': {
                    'name': 'CSBO-00001',
                    'option_label': 'Small dog',
                    'default_rate': 25000,
                  },
                },
              ],
            },
          },
        });
      }),
    );

    final services = await client.listPetCareServices(
      petId: 'PET-001',
      status: 'pending',
      category: 'CategoryCareServices-0001',
      dateFrom: DateTime(2026, 7),
      dateTo: DateTime(2026, 7, 31),
    );

    expect(services.single.id, 'PetCareService-00001');
    expect(services.single.petName, 'Loli');
    expect(services.single.template?.arabicName, 'العناية');
    expect(services.single.categoryDetails?.categoryName, 'Pet care');
    expect(services.single.optionDetails?.optionLabel, 'Small dog');
  });

  test('getPetCareService fetches one guardian service', () async {
    final store = await _authedStore();
    final client = AlkokhMobileClient(
      tokenStore: store,
      httpClient: MockClient((request) async {
        expect(
          request.url.path,
          '/api/method/pet_app.api.guardian_portal.get_pet_care_service',
        );
        expect(request.url.queryParameters['service'], 'PetCareService-00001');
        return _json({
          'message': {
            'ok': true,
            'data': {
              'service': {
                'name': 'PetCareService-00001',
                'service_name': 'Grooming',
                'status': 'completed',
                'care_service': {'name': 'CareService-00001'},
              },
            },
          },
        });
      }),
    );

    final service = await client.getPetCareService('PetCareService-00001');

    expect(service.id, 'PetCareService-00001');
    expect(service.status, 'completed');
  });

  test('bookAppointment resolves current guardian when omitted', () async {
    final store = await _authedStore();
    var call = 0;
    final client = AlkokhMobileClient(
      tokenStore: store,
      httpClient: MockClient((request) async {
        call++;
        expect(request.headers['Authorization'], 'Bearer access');
        if (call == 1) {
          expect(request.url.path, '/api/method/pet_app.api.mobile.profile.me');
          return _json({
            'message': {
              'ok': true,
              'data': {'guardian_id': 'GUARDIAN-001'},
            },
          });
        }

        expect(
          request.url.path,
          '/api/method/pet_app.api.scheduling.book_appointment',
        );
        final body = jsonDecode(request.body) as Map<String, Object?>;
        final data = body['data'] as Map<String, Object?>;
        expect(data['pet'], 'PET-001');
        expect(data['guardian'], 'GUARDIAN-001');
        expect(data['scheduled_time'], '2026-07-24 10:15:00');
        expect(data['appointment_type'], 'visit');
        expect(data['idempotency_key'], 'appt-1');
        return _json({
          'message': {
            'ok': true,
            'data': {
              'appointment': {
                'name': 'APPT-001',
                'status': 'Open',
                'scheduled_time': '2026-07-24 10:15:00',
                'pet': 'PET-001',
                'guardian': 'GUARDIAN-001',
                'duration_minutes': 30,
              },
            },
          },
        });
      }),
    );

    final appointment = await client.bookAppointment(
      petId: 'PET-001',
      scheduledTime: DateTime(2026, 7, 24, 10, 15),
      idempotencyKey: 'appt-1',
    );

    expect(appointment.id, 'APPT-001');
    expect(appointment.durationMinutes, 30);
    expect(call, 2);
  });

  test('rescheduleAppointment posts appointment update payload', () async {
    final store = await _authedStore();
    final client = AlkokhMobileClient(
      tokenStore: store,
      httpClient: MockClient((request) async {
        expect(
          request.url.path,
          '/api/method/pet_app.api.scheduling.reschedule_appointment',
        );
        final body = jsonDecode(request.body) as Map<String, Object?>;
        final data = body['data'] as Map<String, Object?>;
        expect(data['appointment'], 'APPT-001');
        expect(data['scheduled_time'], '2026-07-25 11:00:00');
        expect(data['doctor'], 'DOC-001');
        return _json({
          'message': {
            'ok': true,
            'data': {
              'appointment': {
                'name': 'APPT-001',
                'status': 'Open',
                'scheduled_time': '2026-07-25 11:00:00',
                'doctor': 'DOC-001',
              },
            },
          },
        });
      }),
    );

    final appointment = await client.rescheduleAppointment(
      'APPT-001',
      scheduledTime: DateTime(2026, 7, 25, 11),
      doctor: 'DOC-001',
    );

    expect(appointment.scheduledTime, '2026-07-25 11:00:00');
    expect(appointment.doctor, 'DOC-001');
  });

  test(
    'cancelAppointment posts reason and maps cancelled appointment',
    () async {
      final store = await _authedStore();
      final client = AlkokhMobileClient(
        tokenStore: store,
        httpClient: MockClient((request) async {
          expect(
            request.url.path,
            '/api/method/pet_app.api.scheduling.cancel_appointment',
          );
          final body = jsonDecode(request.body) as Map<String, Object?>;
          final data = body['data'] as Map<String, Object?>;
          expect(data['appointment'], 'APPT-001');
          expect(data['reason'], 'Cannot attend');
          return _json({
            'message': {
              'ok': true,
              'data': {
                'appointment': {'name': 'APPT-001', 'status': 'Cancelled'},
              },
            },
          });
        }),
      );

      final appointment = await client.cancelAppointment(
        'APPT-001',
        reason: 'Cannot attend',
      );

      expect(appointment.status, 'Cancelled');
    },
  );

  test('error envelope throws typed SDK exception', () async {
    final client = AlkokhMobileClient(
      httpClient: MockClient((request) async {
        return _json({
          'message': {
            'error': {
              'code': 'auth.wrong_credentials',
              'message': 'Invalid phone or password',
            },
          },
        }, statusCode: 401);
      }),
    );

    expect(
      () => client.signIn(phone: '07700000001', password: 'Mobile@1234'),
      throwsA(
        isA<AlkokhMobileException>()
            .having((error) => error.code, 'code', 'auth.wrong_credentials')
            .having((error) => error.statusCode, 'statusCode', 401),
      ),
    );
  });

  test('four-key ok:false envelope at HTTP 200 throws instead of parsing empty', () async {
    final client = AlkokhMobileClient(
      tokenStore: await _authedStore(),
      httpClient: MockClient((request) async {
        expect(
          request.url.path,
          '/api/method/pet_app.api.scheduling.book_appointment',
        );
        // What @standardize_response emits on failure: no `error` key, HTTP 200.
        return _json({
          'message': {
            'ok': false,
            'data': <String, Object?>{},
            'meta': {'code': 'ValidationError'},
            'errors': [
              {
                'message': 'That slot is already taken.',
                'details': 'Traceback (most recent call last): ...',
              },
            ],
          },
        });
      }),
    );

    await expectLater(
      () => client.bookAppointment(
        petId: 'PET-0001',
        guardianId: 'GUARDIAN-0001',
        scheduledTime: DateTime(2026, 9, 1, 10),
      ),
      throwsA(
        isA<AlkokhMobileException>()
            .having((e) => e.code, 'code', 'ValidationError')
            .having((e) => e.message, 'message', 'That slot is already taken.')
            // errors[0].details is a server traceback and must never be surfaced.
            .having((e) => e.details, 'details', isNull),
      ),
    );
  });

  test('listHomeProducts resolves a custom block through home_block_v2', () async {
    final client = AlkokhMobileClient(
      httpClient: MockClient((request) async {
        expect(
          request.url.path,
          '/api/method/pet_app.api.mobile.catalog.home_block_v2',
        );
        expect(request.url.queryParameters['block_id'], 'featured-products');
        expect(request.url.queryParameters['filter_key'], 'dog');
        expect(request.url.queryParameters['limit_start'], '20');
        expect(request.url.queryParameters['limit_page_length'], '20');
        return _json({
          'message': {
            'ok': true,
            'data': {
              'block_id': 'featured-products',
              'title': 'Featured',
              'data': {
                'products': [
                  {
                    'id': 'PROD-9',
                    'name': 'Featured Chew',
                    'price': 12000,
                    'effective_price': 12000,
                    'currency': 'IQD',
                    'in_stock': true,
                  },
                ],
              },
              'total': 60,
              'limit_start': 20,
              'limit_page_length': 20,
              'has_more': true,
            },
          },
        });
      }),
    );

    final page = await client.listHomeProducts(
      listId: 'featured-products',
      filter: 'dog',
      cursor: '20',
    );
    expect(page.items.single.id, 'PROD-9');
    expect(page.hasMore, isTrue);
    // Offset pagination is mapped onto the SDK's cursor contract.
    expect(page.nextCursor, '40');
  });

  test('listHomeProducts falls back to list_products when no home block exists', () async {
    var call = 0;
    final client = AlkokhMobileClient(
      httpClient: MockClient((request) async {
        switch (call++) {
          case 0:
            expect(
              request.url.path,
              '/api/method/pet_app.api.mobile.catalog.home_block_v2',
            );
            // An unpublished site 404s for every block id, system lists included.
            return _json({
              'message': {
                'error': {
                  'code': 'catalog.not_found',
                  'message': 'Home block was not found.',
                },
              },
            }, statusCode: 404);
          case 1:
            expect(
              request.url.path,
              '/api/method/pet_app.api.mobile.catalog.list_products',
            );
            expect(request.url.queryParameters['list'], 'best-sellers');
            return _json({
              'message': {
                'ok': true,
                'data': {
                  'items': [
                    {
                      'id': 'PROD-1',
                      'name': 'Dog Food',
                      'price': 20000,
                      'effective_price': 20000,
                      'currency': 'IQD',
                      'in_stock': true,
                    },
                  ],
                  'hasMore': false,
                  'nextCursor': null,
                },
              },
            });
        }
        fail('Unexpected request ${request.url.path}');
      }),
    );

    final page = await client.listHomeProducts(listId: 'best-sellers');
    expect(call, 2);
    expect(page.items.single.id, 'PROD-1');
    expect(page.hasMore, isFalse);
  });

  test('address notes round-trip through create and update', () async {
    var call = 0;
    final client = AlkokhMobileClient(
      tokenStore: await _authedStore(),
      httpClient: MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, Object?>;
        if (call++ == 0) {
          expect(
            request.url.path,
            '/api/method/pet_app.api.mobile.addresses.create_address',
          );
          expect(body['notes'], 'gate code 4471');
          expect(body['area'], 'Karrada');
        } else {
          expect(
            request.url.path,
            '/api/method/pet_app.api.mobile.addresses.update_address',
          );
          expect(body['notes'], 'call on arrival');
        }
        return _json({
          'message': {
            'ok': true,
            'data': {
              'id': 'ADDRESS-0001',
              'address_line1': 'House 12, Street 4',
              'city': 'Baghdad',
              'area': 'Karrada',
              'notes': call == 1 ? 'gate code 4471' : 'call on arrival',
            },
          },
        });
      }),
    );

    final created = await client.createAddress(
      addressLine1: 'House 12, Street 4',
      city: 'Baghdad',
      area: 'Karrada',
      notes: 'gate code 4471',
    );
    expect(created.notes, 'gate code 4471');
    expect(created.area, 'Karrada');

    final updated = await client.updateAddress(
      'ADDRESS-0001',
      notes: 'call on arrival',
    );
    expect(updated.notes, 'call on arrival');
  });

  test('address coordinates round-trip, clear, and refuse a lone value', () async {
    var call = 0;
    final client = AlkokhMobileClient(
      tokenStore: await _authedStore(),
      httpClient: MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, Object?>;
        if (call++ == 0) {
          expect(body['latitude'], 33.315241);
          expect(body['longitude'], 44.3661);
          return _json({
            'message': {
              'ok': true,
              'data': {
                'id': 'ADDRESS-0001',
                'city': 'Baghdad',
                'latitude': 33.315241,
                'longitude': 44.3661,
              },
            },
          });
        }
        // clearCoordinates sends two empty strings, which is how the backend clears.
        expect(body['latitude'], '');
        expect(body['longitude'], '');
        return _json({
          'message': {
            'ok': true,
            'data': {
              'id': 'ADDRESS-0001',
              'city': 'Baghdad',
              'latitude': null,
              'longitude': null,
            },
          },
        });
      }),
    );

    final pinned = await client.createAddress(
      addressLine1: 'House 12, Street 4',
      city: 'Baghdad',
      latitude: 33.315241,
      longitude: 44.3661,
    );
    expect(pinned.latitude, 33.315241);
    expect(pinned.longitude, 44.3661);

    final cleared = await client.updateAddress(
      'ADDRESS-0001',
      clearCoordinates: true,
    );
    expect(cleared.latitude, isNull);
    expect(cleared.longitude, isNull);

    // Caught client-side, before a request is made - call stays at 2.
    expect(
      () => client.createAddress(
        addressLine1: 'House 12, Street 4',
        city: 'Baghdad',
        latitude: 33.315241,
      ),
      throwsA(isA<AlkokhValidationException>()),
    );
    expect(
      () => client.createAddress(
        addressLine1: 'House 12, Street 4',
        city: 'Baghdad',
        latitude: 91,
        longitude: 44.3661,
      ),
      throwsA(isA<AlkokhValidationException>()),
    );
    expect(call, 2);
  });

  test('an unpinned address parses as null, never as (0, 0)', () async {
    final client = AlkokhMobileClient(
      tokenStore: await _authedStore(),
      httpClient: MockClient((request) async {
        return _json({
          'message': {
            'ok': true,
            'data': {
              'items': [
                {'id': 'ADDRESS-0002', 'city': 'Baghdad'},
              ],
              'hasMore': false,
            },
          },
        });
      }),
    );

    final addresses = await client.listAddresses();
    expect(addresses.items.single.latitude, isNull);
    expect(addresses.items.single.longitude, isNull);
  });
}

Future<MemoryTokenStore> _authedStore() async {
  final store = MemoryTokenStore();
  await store.write(
    AuthSession(
      accessToken: 'access',
      refreshToken: 'refresh',
      expiresIn: 3600,
      tokenType: 'Bearer',
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
    ),
  );
  return store;
}

http.Response _json(Map<String, Object?> body, {int statusCode = 200}) {
  return http.Response(
    jsonEncode(body),
    statusCode,
    headers: {'content-type': 'application/json'},
  );
}

http.Response _configResponse({required String currency}) {
  return _json({
    'message': {
      'ok': true,
      'data': {
        'currency': currency,
        'supported_locales': ['en'],
        'default_locale': 'en',
        'feature_flags': {'catalog': true},
      },
    },
  });
}
