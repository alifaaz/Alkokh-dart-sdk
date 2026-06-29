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

    final page = await client.listProducts();

    expect(page.items.single.id, 'Product-001');
    expect(page.items.single.category?.name, 'Food');
    expect(page.items.single.brand?.name, 'Brand');
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
