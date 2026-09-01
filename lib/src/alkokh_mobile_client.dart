import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'alkokh_mobile_exception.dart';
import 'cache_store.dart';
import 'models.dart';
import 'token_store.dart';

typedef RequestIdProvider = String Function();
typedef UploadProgressCallback = void Function(int sentBytes, int totalBytes);

class AlkokhMobileConfig {
  const AlkokhMobileConfig({
    this.baseUrl,
    this.scheme = 'http',
    this.host = '178.105.22.175',
    this.port = 8002,
    this.refreshSkew = const Duration(seconds: 30),
    this.requestIdProvider,
    this.cacheEnabled = false,
    this.cacheTtl = const Duration(minutes: 5),
    this.staleOnError = true,
  });

  final String? baseUrl;
  final String scheme;
  final String host;
  final int? port;
  final Duration refreshSkew;
  final RequestIdProvider? requestIdProvider;
  final bool cacheEnabled;
  final Duration cacheTtl;
  final bool staleOnError;

  String get effectiveBaseUrl {
    final explicitBaseUrl = baseUrl?.trim();
    if (explicitBaseUrl != null && explicitBaseUrl.isNotEmpty) {
      return explicitBaseUrl.replaceFirst(RegExp(r'/+$'), '');
    }
    final uri = Uri(scheme: scheme, host: host, port: port);
    return uri.toString().replaceFirst(RegExp(r'/+$'), '');
  }

  AlkokhMobileConfig copyWith({
    String? baseUrl,
    String? scheme,
    String? host,
    int? port,
    Duration? refreshSkew,
    RequestIdProvider? requestIdProvider,
    bool? cacheEnabled,
    Duration? cacheTtl,
    bool? staleOnError,
  }) {
    return AlkokhMobileConfig(
      baseUrl: baseUrl ?? this.baseUrl,
      scheme: scheme ?? this.scheme,
      host: host ?? this.host,
      port: port ?? this.port,
      refreshSkew: refreshSkew ?? this.refreshSkew,
      requestIdProvider: requestIdProvider ?? this.requestIdProvider,
      cacheEnabled: cacheEnabled ?? this.cacheEnabled,
      cacheTtl: cacheTtl ?? this.cacheTtl,
      staleOnError: staleOnError ?? this.staleOnError,
    );
  }
}

class AlkokhMobileClient {
  AlkokhMobileClient({
    AlkokhMobileConfig config = const AlkokhMobileConfig(),
    String? baseUrl,
    http.Client? httpClient,
    TokenStore? tokenStore,
    CacheStore? cacheStore,
    Duration? refreshSkew,
    RequestIdProvider? requestIdProvider,
  }) : _baseUrl = (baseUrl ?? config.effectiveBaseUrl).replaceFirst(
         RegExp(r'/+$'),
         '',
       ),
       _http = httpClient ?? http.Client(),
       _ownsHttpClient = httpClient == null,
       _tokenStore = tokenStore ?? MemoryTokenStore(),
       _cacheStore = cacheStore ?? MemoryCacheStore(),
       _refreshSkew = refreshSkew ?? config.refreshSkew,
       _requestIdProvider = requestIdProvider ?? config.requestIdProvider,
       _cacheEnabled = config.cacheEnabled,
       _cacheTtl = config.cacheTtl,
       _staleOnError = config.staleOnError;

  final String _baseUrl;
  final http.Client _http;
  final bool _ownsHttpClient;
  final TokenStore _tokenStore;
  final CacheStore _cacheStore;
  final Duration _refreshSkew;
  final RequestIdProvider? _requestIdProvider;
  final bool _cacheEnabled;
  final Duration _cacheTtl;
  final bool _staleOnError;

  Future<AuthSession?> get currentSession => _tokenStore.read();

  void close() {
    if (_ownsHttpClient) {
      _http.close();
    }
  }

  Future<MobileMessage> signUpStart(String phone) async {
    final data = await _postPublic('pet_app.api.mobile.auth.sign_up_start', {
      'phone': _validatePhone(phone),
    });
    return MobileMessage.fromJson(data);
  }

  Future<AuthSession> signUpVerify({
    required String phone,
    required String otp,
    required String password,
    required String fullName,
  }) async {
    final data = await _postPublic('pet_app.api.mobile.auth.sign_up_verify', {
      'phone': _validatePhone(phone),
      'otp': _validateOtp(otp),
      'password': _validatePassword(password),
      'full_name': _validateFullName(fullName),
    });
    return _storeSession(AuthSession.fromJson(data));
  }

  Future<AuthSession> signIn({
    required String phone,
    required String password,
    String? deviceId,
  }) async {
    final body = <String, Object?>{
      'phone': _validatePhone(phone),
      'password': _validatePassword(password),
    };
    if (deviceId != null && deviceId.isNotEmpty) {
      body['device_id'] = deviceId;
    }

    final data = await _postPublic('pet_app.api.mobile.auth.sign_in', body);
    return _storeSession(AuthSession.fromJson(data));
  }

  Future<AuthSession> refresh() async {
    final session = await _tokenStore.read();
    final refreshToken = session?.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      throw AlkokhMobileException(
        code: 'auth.token_invalid',
        message: 'Refresh token is missing.',
        statusCode: 401,
      );
    }

    final data = await _postPublic('pet_app.api.mobile.auth.refresh', {
      'refresh_token': refreshToken,
    });
    return _storeSession(
      AuthSession.fromJson(data, existingRefreshToken: refreshToken),
    );
  }

  Future<void> signOut() async {
    final session = await _tokenStore.read();
    final refreshToken = session?.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      await _tokenStore.clear();
      return;
    }

    try {
      await _postPublic('pet_app.api.mobile.auth.sign_out', {
        'refresh_token': refreshToken,
      });
    } finally {
      await _tokenStore.clear();
    }
  }

  Future<MobileMessage> passwordResetRequest(String phone) async {
    final data = await _postPublic(
      'pet_app.api.mobile.auth.password_reset_request',
      {'phone': _validatePhone(phone)},
    );
    return MobileMessage.fromJson(data);
  }

  Future<ResetToken> passwordResetVerify({
    required String phone,
    required String otp,
  }) async {
    final data = await _postPublic(
      'pet_app.api.mobile.auth.password_reset_verify',
      {'phone': _validatePhone(phone), 'otp': _validateOtp(otp)},
    );
    return ResetToken.fromJson(data);
  }

  Future<void> passwordResetConfirm({
    required String resetToken,
    required String newPassword,
  }) async {
    await _postPublic('pet_app.api.mobile.auth.password_reset_confirm', {
      'reset_token': resetToken.trim(),
      'new_password': _validatePassword(newPassword),
    });
  }

  Future<MobileAppConfig> getConfig({bool forceRefresh = false}) async {
    final data = await _getPublicCached(
      'pet_app.api.mobile.config.get_config',
      forceRefresh: forceRefresh,
    );
    return MobileAppConfig.fromJson(data);
  }

  Future<SupportContact> getSupportContact({bool forceRefresh = false}) async {
    final data = await _getPublicCached(
      'pet_app.api.mobile.config.support_contact',
      forceRefresh: forceRefresh,
    );
    return SupportContact.fromJson(data);
  }

  Future<StaticContent> getContent(
    String key, {
    bool forceRefresh = false,
  }) async {
    final data = await _getPublicCached(
      'pet_app.api.mobile.config.content',
      query: {'key': key},
      forceRefresh: forceRefresh,
    );
    return StaticContent.fromJson(data);
  }

  Future<MobileProfile> getMe() async {
    final data = await _getAuthed('pet_app.api.mobile.profile.me');
    return MobileProfile.fromJson(data);
  }

  Future<MobileProfile> updateMe({
    String? fullName,
    String? emailId,
    String? city,
    String? addressLine1,
    String? country,
  }) async {
    final body = <String, Object?>{};
    if (fullName != null) body['full_name'] = _validateFullName(fullName);
    if (emailId != null) body['email_id'] = emailId;
    if (city != null) body['city'] = city;
    if (addressLine1 != null) body['address_line1'] = addressLine1;
    if (country != null) body['country'] = country;
    if (body.isEmpty) {
      throw AlkokhValidationException('No profile fields were supplied.');
    }
    final data = await _postAuthed(
      'pet_app.api.mobile.profile.update_me',
      body,
    );
    return MobileProfile.fromJson(data);
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _postAuthed('pet_app.api.mobile.profile.change_password', {
      'current_password': currentPassword,
      'new_password': _validatePassword(newPassword),
    });
    await _tokenStore.clear();
  }

  Future<PhoneChangeStart> phoneChangeStart(String newPhone) async {
    final data = await _postAuthed(
      'pet_app.api.mobile.profile.phone_change_start',
      {'new_phone': _validatePhone(newPhone)},
    );
    return PhoneChangeStart.fromJson(data);
  }

  Future<MobileProfile> phoneChangeVerify({
    required String otp,
    String? newPhone,
  }) async {
    final data =
        await _postAuthed('pet_app.api.mobile.profile.phone_change_verify', {
          'otp': _validateOtp(otp),
          if (newPhone != null) 'new_phone': _validatePhone(newPhone),
        });
    await _tokenStore.clear();
    return MobileProfile.fromJson(_stringMap(data['profile']));
  }

  Future<AvatarUploadResult> uploadAvatar({
    required List<int> bytes,
    required String filename,
    UploadProgressCallback? onProgress,
  }) async {
    final data = await _postMultipartAuthed(
      'pet_app.api.mobile.profile.upload_avatar',
      bytes: bytes,
      filename: filename,
      onProgress: onProgress,
    );
    return AvatarUploadResult.fromJson(data);
  }

  Future<void> deleteAccount() async {
    try {
      await _postAuthed('pet_app.api.mobile.profile.delete_account', {});
    } finally {
      await _tokenStore.clear();
    }
  }

  Future<MobileDevice> registerDevice({
    required String fcmToken,
    String platform = 'unknown',
    String? deviceId,
  }) async {
    final data =
        await _postAuthed('pet_app.api.mobile.devices.register_device', {
          'fcm_token': _validateRequiredText(fcmToken, 'FCM token'),
          'platform': platform,
          if (deviceId != null && deviceId.isNotEmpty) 'device_id': deviceId,
        });
    return MobileDevice.fromJson(data);
  }

  Future<MobileDeviceState> deleteDevice(String fcmToken) async {
    final data = await _postAuthed('pet_app.api.mobile.devices.delete_device', {
      'fcm_token': _validateRequiredText(fcmToken, 'FCM token'),
    });
    return MobileDeviceState.fromJson(data);
  }

  Future<PagedResult<MobileAddress>> listAddresses({
    bool includeDisabled = false,
  }) async {
    final data = await _getAuthed(
      'pet_app.api.mobile.addresses.list_addresses',
      {if (includeDisabled) 'include_disabled': 1},
    );
    return PagedResult(
      items: _listOfMaps(data['items']).map(MobileAddress.fromJson).toList(),
      hasMore: data['hasMore'] == true,
      nextCursor: data['nextCursor'] as String?,
    );
  }

  Future<MobileAddress> getAddress(String addressId) async {
    final data = await _getAuthed('pet_app.api.mobile.addresses.get_address', {
      'address': addressId,
    });
    return MobileAddress.fromJson(data);
  }

  Future<MobileAddress> createAddress({
    String? title,
    required String addressLine1,
    String? addressLine2,
    required String city,
    String? area,
    String? state,
    String? country,
    String? pincode,
    String? phone,
    String? emailId,
    String? notes,
    double? latitude,
    double? longitude,
    bool isDefault = false,
  }) async {
    final body = _addressBody(
      title: title,
      addressLine1: _validateRequiredText(addressLine1, 'Address line 1'),
      addressLine2: addressLine2,
      city: _validateRequiredText(city, 'City'),
      area: area,
      state: state,
      country: country,
      pincode: pincode,
      phone: phone,
      emailId: emailId,
      notes: notes,
      latitude: latitude,
      longitude: longitude,
    );
    if (isDefault) body['is_default'] = 1;
    final data = await _postAuthed(
      'pet_app.api.mobile.addresses.create_address',
      body,
    );
    return MobileAddress.fromJson(data);
  }

  Future<MobileAddress> updateAddress(
    String addressId, {
    String? title,
    String? addressLine1,
    String? addressLine2,
    String? city,
    String? area,
    String? state,
    String? country,
    String? pincode,
    String? phone,
    String? emailId,
    String? notes,
    double? latitude,
    double? longitude,
    bool clearCoordinates = false,
    bool? isDefault,
  }) async {
    final body = _addressBody(
      title: title,
      addressLine1: addressLine1,
      addressLine2: addressLine2,
      city: city,
      area: area,
      state: state,
      country: country,
      pincode: pincode,
      phone: phone,
      emailId: emailId,
      notes: notes,
      latitude: latitude,
      longitude: longitude,
      clearCoordinates: clearCoordinates,
    );
    if (isDefault != null) body['is_default'] = isDefault ? 1 : 0;
    if (body.isEmpty) {
      throw AlkokhValidationException('No address fields were supplied.');
    }
    body['address'] = addressId;
    final data = await _postAuthed(
      'pet_app.api.mobile.addresses.update_address',
      body,
    );
    return MobileAddress.fromJson(data);
  }

  Future<MobileAddress> setDefaultAddress(String addressId) async {
    final data = await _postAuthed('pet_app.api.mobile.addresses.set_default', {
      'address': addressId,
    });
    return MobileAddress.fromJson(data);
  }

  Future<void> deleteAddress(String addressId) async {
    await _postAuthed('pet_app.api.mobile.addresses.delete_address', {
      'address': addressId,
    });
  }

  Future<List<SupportedCity>> listSupportedCities() async {
    final data = await _getPublic('pet_app.api.mobile.addresses.cities');
    return _listOfMaps(data['items']).map(SupportedCity.fromJson).toList();
  }

  Future<ReverseGeocodeResult> reverseGeocode({
    required num latitude,
    required num longitude,
  }) async {
    final data = await _getPublic('pet_app.api.mobile.addresses.reverse', {
      'lat': latitude,
      'lng': longitude,
    });
    return ReverseGeocodeResult.fromJson(data);
  }

  Future<MobileHome> getHome({String? lang, bool forceRefresh = false}) async {
    final data = await _getPublicCached(
      'pet_app.api.mobile.catalog.home_v2',
      query: {if (lang != null && lang.isNotEmpty) 'lang': lang},
      forceRefresh: forceRefresh,
    );
    return MobileHome.fromJson(data);
  }

  Future<PagedResult<CatalogProduct>> listProducts({
    String? listId,
    String? category,
    String? brandId,
    String? filter,
    String? tag,
    num? minPrice,
    num? maxPrice,
    bool? inStock,
    String? sort,
    int limit = 20,
    String? cursor,
    bool forceRefresh = false,
  }) async {
    final query = <String, Object?>{'limit': limit};
    if (listId != null && listId.isNotEmpty) query['list'] = listId;
    if (category != null && category.isNotEmpty) query['category'] = category;
    if (brandId != null && brandId.isNotEmpty) query['brandId'] = brandId;
    if (filter != null && filter.isNotEmpty) query['filter'] = filter;
    if (tag != null && tag.isNotEmpty) query['tag'] = tag;
    if (minPrice != null) query['minPrice'] = minPrice;
    if (maxPrice != null) query['maxPrice'] = maxPrice;
    if (inStock != null) query['inStock'] = inStock ? 1 : 0;
    if (sort != null && sort.isNotEmpty) query['sort'] = sort;
    if (cursor != null && cursor.isNotEmpty) query['cursor'] = cursor;

    final data = await _getPublicCached(
      'pet_app.api.mobile.catalog.list_products',
      query: query,
      forceRefresh: forceRefresh,
    );
    return PagedResult(
      items: _listOfMaps(data['items']).map(CatalogProduct.fromJson).toList(),
      hasMore: data['hasMore'] == true,
      nextCursor: data['nextCursor'] as String?,
    );
  }

  /// The "Show All" page behind a home product-list block.
  ///
  /// Goes to `catalog.home_block_v2`, which resolves any block id in the published home
  /// snapshot. The previous route, `catalog.list_products?list=`, resolves only three
  /// hardcoded ids (`best-sellers`, `recently-added`, `back-in-stock`) via
  /// `_home_product_list_config`, so every product list an admin created rendered in
  /// `home_v2` and then 400'd with "Unknown product list" on Show All.
  ///
  /// The fallback is not belt-and-braces. Neither endpoint covers every case: on a site
  /// with no active publication `home_block_v2` 404s for all ids, while `list_products`
  /// still serves the three system lists. Trying the block first and falling back on
  /// `catalog.not_found` fixes custom blocks without regressing system lists on an
  /// unpublished site. A custom block on an unpublished site has genuinely nothing to
  /// show, and surfaces the backend's own error.
  ///
  /// [tag] has no equivalent on `home_block_v2` and routes straight to the old endpoint.
  Future<PagedResult<HomeProductCard>> listHomeProducts({
    required String listId,
    String? filter,
    String? tag,
    String? locale,
    int limit = 20,
    String? cursor,
    bool forceRefresh = false,
  }) async {
    if (tag == null || tag.isEmpty) {
      try {
        final offset = int.tryParse(cursor ?? '') ?? 0;
        final data = await _getPublicCached(
          'pet_app.api.mobile.catalog.home_block_v2',
          query: {
            'block_id': listId,
            'limit_start': offset,
            'limit_page_length': limit,
            if (filter != null && filter.isNotEmpty) 'filter_key': filter,
            if (locale != null && locale.isNotEmpty) 'locale': locale,
          },
          forceRefresh: forceRefresh,
        );
        final hasMore = data['has_more'] == true;
        final pageLength =
            (data['limit_page_length'] as num?)?.toInt() ?? limit;
        final start = (data['limit_start'] as num?)?.toInt() ?? offset;
        return PagedResult(
          items: _listOfMaps(_stringMap(data['data'])['products'])
              .map(HomeProductCard.fromJson)
              .toList(),
          hasMore: hasMore,
          nextCursor: hasMore ? '${start + pageLength}' : null,
        );
      } on AlkokhMobileException catch (error) {
        if (error.code != 'catalog.not_found') rethrow;
      }
    }

    final data = await _getPublicCached(
      'pet_app.api.mobile.catalog.list_products',
      query: {
        'list': listId,
        'limit': limit,
        if (filter != null && filter.isNotEmpty) 'filter': filter,
        if (tag != null && tag.isNotEmpty) 'tag': tag,
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      },
      forceRefresh: forceRefresh,
    );
    return PagedResult(
      items: _listOfMaps(data['items']).map(HomeProductCard.fromJson).toList(),
      hasMore: data['hasMore'] == true,
      nextCursor: data['nextCursor'] as String?,
    );
  }

  Future<CatalogProduct> getProduct(
    String productId, {
    bool forceRefresh = false,
  }) async {
    final data = await _getPublicCached(
      'pet_app.api.mobile.catalog.get_product',
      query: {'product': productId},
      forceRefresh: forceRefresh,
    );
    return CatalogProduct.fromJson(data);
  }

  Future<List<CatalogCategory>> listCategories({
    String? parent,
    String? search,
    bool forceRefresh = false,
  }) async {
    final data = await _getPublicCached(
      'pet_app.api.mobile.catalog.list_categories',
      query: {
        if (parent != null) 'parent': parent,
        if (search != null) 'search': search,
      },
      forceRefresh: forceRefresh,
    );
    return _listOfMaps(data['items']).map(CatalogCategory.fromJson).toList();
  }

  Future<List<CatalogBrand>> listBrands({
    String? search,
    int limit = 100,
    bool forceRefresh = false,
  }) async {
    final data = await _getPublicCached(
      'pet_app.api.mobile.catalog.list_brands',
      query: {'limit': limit, if (search != null) 'search': search},
      forceRefresh: forceRefresh,
    );
    return _listOfMaps(data['items']).map(CatalogBrand.fromJson).toList();
  }

  Future<PagedResult<CatalogProduct>> searchProducts({
    required String query,
    int limit = 20,
    String? cursor,
    bool forceRefresh = false,
  }) async {
    final data = await _getPublicCached(
      'pet_app.api.mobile.catalog.search',
      query: {
        'q': query,
        'limit': limit,
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      },
      forceRefresh: forceRefresh,
    );
    return PagedResult(
      items: _listOfMaps(data['items']).map(CatalogProduct.fromJson).toList(),
      hasMore: data['hasMore'] == true,
      nextCursor: data['nextCursor'] as String?,
    );
  }

  Future<List<ProductSuggestion>> suggestProducts(
    String query, {
    int limit = 8,
    bool forceRefresh = false,
  }) async {
    final data = await _getPublicCached(
      'pet_app.api.mobile.catalog.suggest',
      query: {'q': query, 'limit': limit},
      forceRefresh: forceRefresh,
    );
    return _listOfMaps(data['items']).map(ProductSuggestion.fromJson).toList();
  }

  Future<PagedResult<MobileFavorite>> listFavorites({
    int limit = 20,
    String? cursor,
  }) async {
    final data = await _getAuthed(
      'pet_app.api.mobile.favorites.list_favorites',
      {
        'limit': limit,
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      },
    );
    return PagedResult(
      items: _listOfMaps(data['items']).map(MobileFavorite.fromJson).toList(),
      hasMore: data['hasMore'] == true,
      nextCursor: data['nextCursor'] as String?,
    );
  }

  Future<MobileFavoriteState> toggleFavorite(String productId) async {
    final data = await _postAuthed(
      'pet_app.api.mobile.favorites.toggle_favorite',
      {'product': productId},
    );
    return MobileFavoriteState.fromJson(data);
  }

  Future<MobileFavoriteState> removeFavorite(String productId) async {
    final data = await _postAuthed(
      'pet_app.api.mobile.favorites.remove_favorite',
      {'product': productId},
    );
    return MobileFavoriteState.fromJson(data);
  }

  Future<ProductReviewPage> listProductReviews(
    String productId, {
    int limit = 20,
    String? cursor,
    bool forceRefresh = false,
  }) async {
    final data = await _getPublicCached(
      'pet_app.api.mobile.reviews.list_product_reviews',
      query: {
        'product': productId,
        'limit': limit,
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      },
      forceRefresh: forceRefresh,
    );
    return ProductReviewPage.fromJson(data);
  }

  Future<ProductReview> upsertProductReview(
    String productId, {
    required int rating,
    String? notes,
  }) async {
    final data =
        await _postAuthed('pet_app.api.mobile.reviews.upsert_product_review', {
          'product': productId,
          'rating': _validateRating(rating),
          if (notes != null) 'notes': notes,
        });
    await _clearProductReviewCache(productId);
    return ProductReview.fromJson(data);
  }

  Future<List<RecentSearch>> listRecentSearches() async {
    final data = await _getAuthed(
      'pet_app.api.mobile.search_history.list_recent',
    );
    return _listOfMaps(data['items']).map(RecentSearch.fromJson).toList();
  }

  Future<List<RecentSearch>> saveRecentSearch(String query) async {
    final data = await _postAuthed(
      'pet_app.api.mobile.search_history.save_recent',
      {'q': _validateRequiredText(query, 'Search query')},
    );
    return _listOfMaps(data['items']).map(RecentSearch.fromJson).toList();
  }

  Future<List<RecentSearch>> clearRecentSearches() async {
    final data = await _postAuthed(
      'pet_app.api.mobile.search_history.clear_recent',
      {},
    );
    return _listOfMaps(data['items']).map(RecentSearch.fromJson).toList();
  }

  Future<PagedResult<MobilePet>> listPets({
    int limit = 20,
    String? cursor,
    bool includeDisabled = false,
  }) async {
    final data = await _getAuthed('pet_app.api.mobile.pets.list_pets', {
      'limit': limit,
      if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      if (includeDisabled) 'include_disabled': 1,
    });
    return PagedResult(
      items: _listOfMaps(data['items']).map(MobilePet.fromJson).toList(),
      hasMore: data['hasMore'] == true,
      nextCursor: data['nextCursor'] as String?,
    );
  }

  Future<List<PetBreed>> listPetBreeds({
    String? animalType,
    String? animalSpecies,
    String? search,
    int limit = 100,
  }) async {
    final data = await _getAuthed('pet_app.api.mobile.pets.list_breeds', {
      'limit': limit,
      if (animalType != null && animalType.trim().isNotEmpty)
        'animal_type': animalType.trim(),
      if (animalSpecies != null && animalSpecies.trim().isNotEmpty)
        'animal_species': animalSpecies.trim(),
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
    });
    return _listOfMaps(data['items']).map(PetBreed.fromJson).toList();
  }

  Future<MobilePet> getPet(String petId) async {
    final data = await _getAuthed('pet_app.api.mobile.pets.get_pet', {
      'pet': petId,
    });
    return MobilePet.fromJson(data);
  }

  Future<MobilePet> createPet({
    required String name,
    String? species,
    String? type,
    String? breed,
    String? birthDate,
    String? registrationDate,
    String? color,
    String? gender,
    num? weight,
    num? height,
    String? bloodType,
    String? play,
    String? activityExercise,
    String? foodBrand,
    String? foodType,
    String? description,
    String? note,
  }) async {
    final body = _petBody(
      name: _validatePetName(name),
      species: species,
      type: type,
      breed: breed,
      birthDate: birthDate,
      registrationDate: registrationDate,
      color: color,
      gender: gender,
      weight: weight,
      height: height,
      bloodType: bloodType,
      play: play,
      activityExercise: activityExercise,
      foodBrand: foodBrand,
      foodType: foodType,
      description: description,
      note: note,
    );
    final data = await _postAuthed('pet_app.api.mobile.pets.create_pet', body);
    return MobilePet.fromJson(data);
  }

  Future<MobilePet> updatePet(
    String petId, {
    String? name,
    String? species,
    String? type,
    String? breed,
    String? birthDate,
    String? registrationDate,
    String? color,
    String? gender,
    num? weight,
    num? height,
    String? bloodType,
    String? play,
    String? activityExercise,
    String? foodBrand,
    String? foodType,
    String? description,
    String? note,
  }) async {
    final body = _petBody(
      name: name == null ? null : _validatePetName(name),
      species: species,
      type: type,
      breed: breed,
      birthDate: birthDate,
      registrationDate: registrationDate,
      color: color,
      gender: gender,
      weight: weight,
      height: height,
      bloodType: bloodType,
      play: play,
      activityExercise: activityExercise,
      foodBrand: foodBrand,
      foodType: foodType,
      description: description,
      note: note,
    );
    if (body.isEmpty) {
      throw AlkokhValidationException('No pet fields were supplied.');
    }
    body['pet'] = petId;
    final data = await _postAuthed('pet_app.api.mobile.pets.update_pet', body);
    return MobilePet.fromJson(data);
  }

  Future<MobilePet> disablePet(String petId) async {
    final data = await _postAuthed('pet_app.api.mobile.pets.disable_pet', {
      'pet': petId,
    });
    return MobilePet.fromJson(data);
  }

  Future<PetPhotoUploadResult> uploadPetPhoto(
    String petId, {
    required List<int> bytes,
    required String filename,
    UploadProgressCallback? onProgress,
  }) async {
    final data = await _postMultipartAuthed(
      'pet_app.api.mobile.pets.upload_photo',
      bytes: bytes,
      filename: filename,
      fields: {'pet': petId},
      onProgress: onProgress,
    );
    return PetPhotoUploadResult.fromJson(data);
  }

  Future<List<PetMedicalEvent>> getPetMedicalTimeline(
    String petId, {
    int limit = 50,
  }) async {
    final data = await _getAuthed('pet_app.api.mobile.pets.medical_timeline', {
      'pet': petId,
      'limit': limit,
    });
    return _listOfMaps(data['items']).map(PetMedicalEvent.fromJson).toList();
  }

  Future<List<PetDocument>> getPetDocuments(String petId) async {
    final data = await _getAuthed('pet_app.api.mobile.pets.documents', {
      'pet': petId,
    });
    return _listOfMaps(data['items']).map(PetDocument.fromJson).toList();
  }

  Future<PagedResult<PetMedicalRecord>> listPetMedicalRecords(
    String petId, {
    String? recordType,
    int limit = 50,
    String? cursor,
  }) async {
    final data =
        await _getAuthed('pet_app.api.mobile.pets.list_medical_records', {
          'pet': petId,
          'limit': limit,
          if (recordType != null && recordType.isNotEmpty)
            'record_type': recordType,
          if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
        });
    return PagedResult(
      items: _listOfMaps(data['items']).map(PetMedicalRecord.fromJson).toList(),
      hasMore: data['hasMore'] == true,
      nextCursor: data['nextCursor'] as String?,
    );
  }

  Future<PetMedicalRecord> addPetMedicalRecord(
    String petId, {
    required String recordType,
    String? name,
    String? vaccineName,
    String? vaccineType,
    String? medication,
    String? medicationName,
    String? dose,
    String? batchNo,
    String? administeredOn,
    String? nextDueDate,
    bool? reminderEnabled,
    String? notes,
  }) async {
    final body = _medicalRecordBody(
      petId,
      recordType: recordType,
      name: name,
      vaccineName: vaccineName,
      vaccineType: vaccineType,
      medication: medication,
      medicationName: medicationName,
      dose: dose,
      batchNo: batchNo,
      administeredOn: administeredOn,
      nextDueDate: nextDueDate,
      reminderEnabled: reminderEnabled,
      notes: notes,
    );
    final data = await _postAuthed(
      'pet_app.api.mobile.pets.add_medical_record',
      body,
    );
    return PetMedicalRecord.fromJson(data);
  }

  Future<PetMedicalRecord> updatePetMedicalRecord(
    String petId,
    String recordId, {
    String? recordType,
    String? name,
    String? vaccineName,
    String? vaccineType,
    String? medication,
    String? medicationName,
    String? dose,
    String? batchNo,
    String? administeredOn,
    String? nextDueDate,
    bool? reminderEnabled,
    String? notes,
  }) async {
    final body = _medicalRecordBody(
      petId,
      recordType: recordType,
      name: name,
      vaccineName: vaccineName,
      vaccineType: vaccineType,
      medication: medication,
      medicationName: medicationName,
      dose: dose,
      batchNo: batchNo,
      administeredOn: administeredOn,
      nextDueDate: nextDueDate,
      reminderEnabled: reminderEnabled,
      notes: notes,
    );
    body['record'] = recordId;
    final data = await _postAuthed(
      'pet_app.api.mobile.pets.update_medical_record',
      body,
    );
    return PetMedicalRecord.fromJson(data);
  }

  Future<void> deletePetMedicalRecord(
    String petId,
    String recordId, {
    String? recordType,
  }) async {
    await _postAuthed('pet_app.api.mobile.pets.delete_medical_record', {
      'pet': petId,
      'record': recordId,
      if (recordType != null && recordType.isNotEmpty)
        'record_type': recordType,
    });
  }

  Future<List<AppointmentType>> listAppointmentTypes() async {
    final data = await _getAuthed(
      'pet_app.api.scheduling.list_appointment_types',
    );
    final rows = _listOfMaps(data['appointment_types']);
    if (rows.isNotEmpty) {
      return rows
          .map(AppointmentType.fromJson)
          .where((type) => type.value.isNotEmpty)
          .toList();
    }

    final values = data['types'];
    if (values is List) {
      return values
          .map((value) => AppointmentType.fromJson({'value': value}))
          .where((type) => type.value.isNotEmpty)
          .toList();
    }
    return const [];
  }

  Future<List<AppointmentSlot>> getAvailableAppointmentSlots({
    required DateTime date,
    String? doctor,
    String? practitioner,
    String? room,
    String serviceType = 'Visit',
    int? durationMinutes,
  }) async {
    final data = await _getAuthed(
      'pet_app.api.scheduling.get_available_slots',
      {
        'date': _formatDate(date),
        if (doctor != null && doctor.trim().isNotEmpty) 'doctor': doctor.trim(),
        if (practitioner != null && practitioner.trim().isNotEmpty)
          'practitioner': practitioner.trim(),
        if (room != null && room.trim().isNotEmpty) 'room': room.trim(),
        'service_type': serviceType.trim().isEmpty
            ? 'Visit'
            : serviceType.trim(),
        if (durationMinutes != null) 'duration_minutes': durationMinutes,
      },
    );
    return _listOfMaps(data['slots']).map(AppointmentSlot.fromJson).toList();
  }

  Future<List<MobileAppointment>> listUpcomingAppointments({
    int limit = 20,
  }) async {
    final data = await _getAuthed(
      'pet_app.api.guardian_portal.get_upcoming_appointments',
      {'limit': limit},
    );
    return _listOfMaps(
      data['appointments'],
    ).map(MobileAppointment.fromJson).toList();
  }

  Future<List<MobileAppointment>> listAppointments({
    String? guardianId,
    String? customerId,
    String? petId,
    String? status,
    DateTime? dateFrom,
    DateTime? dateTo,
    bool futureOnly = false,
    int limit = 50,
    bool currentUserOnly = true,
  }) async {
    final query = <String, Object?>{
      'limit': limit,
      if (petId != null && petId.trim().isNotEmpty) 'pet': petId.trim(),
      if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
      if (dateFrom != null) 'date_from': _formatDate(dateFrom),
      if (dateTo != null) 'date_to': _formatDate(dateTo),
      if (futureOnly) 'future_only': 1,
    };
    if (!currentUserOnly) {
      if (guardianId != null && guardianId.trim().isNotEmpty) {
        query['guardian'] = guardianId.trim();
      }
      if (customerId != null && customerId.trim().isNotEmpty) {
        query['customer'] = customerId.trim();
      }
    }

    final data = await _getAuthed(
      currentUserOnly
          ? 'pet_app.api.guardian_portal.get_appointments'
          : 'pet_app.api.scheduling.list_appointments',
      query,
    );
    return _listOfMaps(
      data['appointments'],
    ).map(MobileAppointment.fromJson).toList();
  }

  Future<List<MobilePetCareService>> listPetCareServices({
    String? petId,
    String? status,
    String? category,
    DateTime? dateFrom,
    DateTime? dateTo,
    int limit = 50,
  }) async {
    final data = await _getAuthed(
      'pet_app.api.guardian_portal.get_pet_care_services',
      {
        'limit': limit,
        if (petId != null && petId.trim().isNotEmpty) 'pet': petId.trim(),
        if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
        if (category != null && category.trim().isNotEmpty)
          'category': category.trim(),
        if (dateFrom != null) 'date_from': _formatDate(dateFrom),
        if (dateTo != null) 'date_to': _formatDate(dateTo),
      },
    );
    return _listOfMaps(
      data['services'],
    ).map(MobilePetCareService.fromJson).toList();
  }

  Future<MobilePetCareService> getPetCareService(String serviceId) async {
    final serviceName = serviceId.trim();
    if (serviceName.isEmpty) {
      throw AlkokhValidationException('Service id is required.');
    }
    final data = await _getAuthed(
      'pet_app.api.guardian_portal.get_pet_care_service',
      {'service': serviceName},
    );
    return MobilePetCareService.fromJson(_stringMap(data['service']));
  }

  Future<MobileAppointment> bookAppointment({
    required String petId,
    String? guardianId,
    required DateTime scheduledTime,
    String appointmentType = 'visit',
    String serviceType = 'Visit',
    String? doctor,
    String? practitioner,
    String? room,
    int? durationMinutes,
    String? note,
    String? clientRequestId,
    String? idempotencyKey,
  }) async {
    final guardian = await _resolveGuardianId(guardianId);
    final body = <String, Object?>{
      'pet': _validateRequiredText(petId, 'Pet'),
      'guardian': guardian,
      'scheduled_time': _formatDateTime(scheduledTime),
      'appointment_type': appointmentType.trim().isEmpty
          ? 'visit'
          : appointmentType.trim(),
      'service_type': serviceType.trim().isEmpty ? 'Visit' : serviceType.trim(),
      if (doctor != null && doctor.trim().isNotEmpty) 'doctor': doctor.trim(),
      if (practitioner != null && practitioner.trim().isNotEmpty)
        'practitioner': practitioner.trim(),
      if (room != null && room.trim().isNotEmpty) 'room': room.trim(),
      if (durationMinutes != null) 'duration_minutes': durationMinutes,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      if (clientRequestId != null && clientRequestId.trim().isNotEmpty)
        'client_request_id': clientRequestId.trim(),
      if (idempotencyKey != null && idempotencyKey.trim().isNotEmpty)
        'idempotency_key': idempotencyKey.trim(),
    };
    final data = await _postAuthed('pet_app.api.scheduling.book_appointment', {
      'data': body,
    });
    return MobileAppointment.fromJson(_stringMap(data['appointment']));
  }

  Future<MobileAppointment> rescheduleAppointment(
    String appointmentId, {
    required DateTime scheduledTime,
    String? doctor,
    String? practitioner,
    String? room,
    int? durationMinutes,
  }) async {
    final body = <String, Object?>{
      'appointment': _validateRequiredText(appointmentId, 'Appointment'),
      'scheduled_time': _formatDateTime(scheduledTime),
      if (doctor != null && doctor.trim().isNotEmpty) 'doctor': doctor.trim(),
      if (practitioner != null && practitioner.trim().isNotEmpty)
        'practitioner': practitioner.trim(),
      if (room != null && room.trim().isNotEmpty) 'room': room.trim(),
      if (durationMinutes != null) 'duration_minutes': durationMinutes,
    };
    final data = await _postAuthed(
      'pet_app.api.scheduling.reschedule_appointment',
      {'data': body},
    );
    return MobileAppointment.fromJson(_stringMap(data['appointment']));
  }

  Future<MobileAppointment> cancelAppointment(
    String appointmentId, {
    String? reason,
  }) async {
    final body = <String, Object?>{
      'appointment': _validateRequiredText(appointmentId, 'Appointment'),
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
    };
    final data = await _postAuthed(
      'pet_app.api.scheduling.cancel_appointment',
      {'data': body},
    );
    return MobileAppointment.fromJson(_stringMap(data['appointment']));
  }

  Future<PagedResult<MobileOrder>> listOrders({
    int limit = 20,
    String? cursor,
    String? status,
  }) async {
    final query = <String, Object?>{'limit': limit};
    if (cursor != null && cursor.isNotEmpty) query['cursor'] = cursor;
    if (status != null && status.isNotEmpty) query['status'] = status;

    final data = await _getAuthed(
      'pet_app.api.mobile.orders.list_orders',
      query,
    );
    final items = _listOfMaps(data['items']).map(MobileOrder.fromJson).toList();
    return PagedResult(
      items: items,
      hasMore: data['hasMore'] == true,
      nextCursor: data['nextCursor'] as String?,
    );
  }

  Future<MobileOrder> getOrder(String orderId) async {
    final data = await _getAuthed('pet_app.api.mobile.orders.get_order', {
      'order': orderId,
    });
    return MobileOrder.fromJson(data);
  }

  Future<OrderQuote> quoteOrder({
    required List<MobileOrderItem> items,
    String? couponCode,
  }) async {
    if (items.isEmpty) {
      throw AlkokhValidationException('Cart is empty.');
    }

    final body = <String, Object?>{
      'items': items.map((item) => item.toPlaceOrderJson()).toList(),
      if (couponCode != null && couponCode.isNotEmpty)
        'coupon_code': couponCode,
    };
    final data = await _postAuthed('pet_app.api.mobile.orders.quote', body);
    return OrderQuote.fromJson(data);
  }

  Future<MobileOrder> placeOrder({
    required List<MobileOrderItem> items,
    String paymentMethod = 'Cash on Delivery',
    num? deliveryLat,
    num? deliveryLng,
    String? shippingAddressName,
    String? couponCode,
    String? shippingRule,
  }) async {
    if (items.isEmpty) {
      throw AlkokhValidationException('Cart is empty.');
    }

    final body = <String, Object?>{
      'items': items.map((item) => item.toPlaceOrderJson()).toList(),
      'payment_method': _normalizePaymentMethod(paymentMethod),
    };
    if (deliveryLat != null) body['delivery_lat'] = deliveryLat;
    if (deliveryLng != null) body['delivery_lng'] = deliveryLng;
    if (shippingAddressName != null && shippingAddressName.isNotEmpty) {
      body['shipping_address_name'] = shippingAddressName;
    }
    if (couponCode != null && couponCode.isNotEmpty) {
      body['coupon_code'] = couponCode;
    }
    if (shippingRule != null && shippingRule.isNotEmpty) {
      body['shipping_rule'] = shippingRule;
    }

    final data = await _postAuthed(
      'pet_app.api.mobile.orders.place_order',
      body,
    );
    return MobileOrder.fromJson(data);
  }

  Future<MobileOrder> cancelOrder(String orderId, {String? reason}) async {
    final data = await _postAuthed('pet_app.api.mobile.orders.cancel_order', {
      'order': orderId,
      if (reason != null && reason.isNotEmpty) 'reason': reason,
    });
    return MobileOrder.fromJson(data);
  }

  Future<ReorderDraft> reorder(String orderId) async {
    final data = await _postAuthed('pet_app.api.mobile.orders.reorder', {
      'order': orderId,
    });
    return ReorderDraft.fromJson(data);
  }

  Future<AuthSession> _storeSession(AuthSession session) async {
    await _tokenStore.write(session);
    return session;
  }

  Future<Map<String, Object?>> _postPublic(
    String method,
    Map<String, Object?> body,
  ) {
    return _request('POST', method, body: body, auth: false);
  }

  Future<Map<String, Object?>> _getPublic(
    String method, [
    Map<String, Object?>? query,
  ]) {
    return _request('GET', method, query: query, auth: false);
  }

  Future<Map<String, Object?>> _getPublicCached(
    String method, {
    Map<String, Object?>? query,
    bool forceRefresh = false,
  }) {
    return _request(
      'GET',
      method,
      query: query,
      auth: false,
      cache: true,
      forceRefresh: forceRefresh,
    );
  }

  Future<Map<String, Object?>> _postAuthed(
    String method,
    Map<String, Object?> body,
  ) {
    return _request('POST', method, body: body, auth: true);
  }

  Future<Map<String, Object?>> _postMultipartAuthed(
    String method, {
    required List<int> bytes,
    required String filename,
    Map<String, String>? fields,
    UploadProgressCallback? onProgress,
    bool retried = false,
  }) async {
    if (bytes.isEmpty) {
      throw AlkokhValidationException('Upload file is empty.');
    }
    final safeFilename = filename.trim();
    if (safeFilename.isEmpty) {
      throw AlkokhValidationException('Upload filename is required.');
    }

    final session = await _sessionForRequest();
    final request = http.MultipartRequest('POST', _uri(method, null))
      ..headers['Accept'] = 'application/json'
      ..headers['Authorization'] = '${session.tokenType} ${session.accessToken}'
      ..fields.addAll(fields ?? const {})
      ..files.add(
        http.MultipartFile(
          'file',
          _progressStream(bytes, onProgress),
          bytes.length,
          filename: safeFilename,
        ),
      );
    _addRequestId(request.headers);

    final streamed = await _http.send(request);
    final response = await http.Response.fromStream(streamed);
    try {
      return _decodeData(response);
    } on AlkokhMobileException catch (error) {
      if (!retried && error.statusCode == 401) {
        await refresh();
        return _postMultipartAuthed(
          method,
          bytes: bytes,
          filename: filename,
          fields: fields,
          onProgress: onProgress,
          retried: true,
        );
      }
      rethrow;
    }
  }

  Future<Map<String, Object?>> _getAuthed(
    String method, [
    Map<String, Object?>? query,
  ]) {
    return _request('GET', method, query: query, auth: true);
  }

  Future<Map<String, Object?>> _request(
    String httpMethod,
    String method, {
    Map<String, Object?>? body,
    Map<String, Object?>? query,
    required bool auth,
    bool retried = false,
    bool cache = false,
    bool forceRefresh = false,
  }) async {
    final shouldCache = cache && _cacheEnabled && !auth && httpMethod == 'GET';
    final cacheKey = shouldCache ? _cacheKey(method, query) : null;
    final cachedEntry = cacheKey == null
        ? null
        : await _cacheStore.read(cacheKey);
    if (cachedEntry != null &&
        !forceRefresh &&
        cachedEntry.isFresh(_cacheTtl, DateTime.now())) {
      return cachedEntry.data;
    }

    final headers = <String, String>{'Accept': 'application/json'};
    if (httpMethod != 'GET') {
      headers['Content-Type'] = 'application/json';
    }
    _addRequestId(headers);
    if (auth) {
      final session = await _sessionForRequest();
      headers['Authorization'] = '${session.tokenType} ${session.accessToken}';
    }

    final uri = _uri(method, query);
    try {
      final response = httpMethod == 'GET'
          ? await _http.get(uri, headers: headers)
          : await _http.post(
              uri,
              headers: headers,
              body: jsonEncode(body ?? {}),
            );
      final data = _decodeData(response);
      if (cacheKey != null) {
        await _cacheStore.write(
          cacheKey,
          CacheEntry(data: data, createdAt: DateTime.now()),
        );
      }
      return data;
    } on AlkokhMobileException catch (error) {
      if (cacheKey != null && _staleOnError && cachedEntry != null) {
        return cachedEntry.data;
      }
      if (auth && !retried && error.statusCode == 401) {
        await refresh();
        return _request(
          httpMethod,
          method,
          body: body,
          query: query,
          auth: auth,
          retried: true,
          cache: cache,
          forceRefresh: forceRefresh,
        );
      }
      rethrow;
    } catch (_) {
      if (cacheKey != null && _staleOnError && cachedEntry != null) {
        return cachedEntry.data;
      }
      rethrow;
    }
  }

  Future<void> _clearProductReviewCache(String productId) {
    final encodedProduct = Uri.encodeQueryComponent(productId);
    final productDetailKey = _cacheKey(
      'pet_app.api.mobile.catalog.get_product',
      {'product': productId},
    );
    return _cacheStore.deleteWhere((key) {
      if (key == productDetailKey) return true;
      if (key.startsWith('pet_app.api.mobile.catalog.home_v2')) return true;
      if (key.startsWith('pet_app.api.mobile.catalog.home_block_v2')) {
        return true;
      }
      if (key.startsWith('pet_app.api.mobile.catalog.list_products')) {
        return true;
      }
      return key.startsWith(
            'pet_app.api.mobile.reviews.list_product_reviews?',
          ) &&
          key.contains('product=$encodedProduct');
    });
  }

  Future<AuthSession> _sessionForRequest() async {
    final session = await _tokenStore.read();
    if (session == null) {
      throw AlkokhMobileException(
        code: 'auth.token_invalid',
        message: 'No active session.',
        statusCode: 401,
      );
    }

    if (session.refreshToken != null && session.expiresWithin(_refreshSkew)) {
      return refresh();
    }
    return session;
  }

  void _addRequestId(Map<String, String> headers) {
    final requestId = _requestIdProvider?.call().trim();
    if (requestId != null && requestId.isNotEmpty) {
      headers['X-Request-Id'] = requestId;
    }
  }

  Stream<List<int>> _progressStream(
    List<int> bytes,
    UploadProgressCallback? onProgress,
  ) async* {
    const chunkSize = 64 * 1024;
    var sent = 0;
    while (sent < bytes.length) {
      final end = sent + chunkSize > bytes.length
          ? bytes.length
          : sent + chunkSize;
      final chunk = bytes.sublist(sent, end);
      sent = end;
      yield chunk;
      onProgress?.call(sent, bytes.length);
    }
  }

  Uri _uri(String method, Map<String, Object?>? query) {
    final uri = Uri.parse('$_baseUrl/api/method/$method');
    if (query == null || query.isEmpty) return uri;

    final queryParameters = <String, String>{};
    for (final entry in query.entries) {
      final value = entry.value;
      if (value != null) queryParameters[entry.key] = value.toString();
    }
    return uri.replace(queryParameters: queryParameters);
  }

  String _cacheKey(String method, Map<String, Object?>? query) {
    if (query == null || query.isEmpty) return method;
    final parts = <String>[];
    final keys = query.keys.toList()..sort();
    for (final key in keys) {
      final value = query[key];
      if (value == null) continue;
      parts.add(
        '${Uri.encodeQueryComponent(key)}='
        '${Uri.encodeQueryComponent(value.toString())}',
      );
    }
    if (parts.isEmpty) return method;
    return '$method?${parts.join('&')}';
  }

  Map<String, Object?> _decodeData(http.Response response) {
    final decoded = response.body.isEmpty
        ? <String, Object?>{}
        : jsonDecode(response.body) as Object?;
    if (decoded is! Map) {
      throw AlkokhMobileException(
        code: 'InvalidResponse',
        message: 'Expected JSON object response.',
        statusCode: response.statusCode,
      );
    }

    final root = decoded.map((key, value) => MapEntry(key.toString(), value));
    final message = _stringMap(root['message']);
    final envelope = message.isEmpty ? root.cast<String, Object?>() : message;

    final error = _stringMap(envelope['error']);
    if (error.isNotEmpty) {
      throw AlkokhMobileException(
        code: error['code'] as String? ?? 'Error',
        message: error['message'] as String? ?? 'Request failed.',
        statusCode: response.statusCode,
        details: error['details'],
      );
    }

    // The four-key envelope reports failure as `ok: false` with the reason in `errors[]`
    // and no `error` key at all, at HTTP 200. Endpoints wrapping `@standardize_response`
    // return it - `pet_app.api.scheduling.book_appointment` is the one on this surface.
    // Without this branch such a refusal fell past the `error` check, past the status
    // check, and into the `data` branch, which returned `{}`: a rejected booking parsed
    // as an empty MobileAppointment instead of throwing.
    //
    // `errors[0].details` is deliberately never read. It carries a server traceback.
    final errors = _listOfMaps(envelope['errors']);
    if (envelope['ok'] == false || errors.isNotEmpty) {
      final first = errors.isEmpty ? const <String, Object?>{} : errors.first;
      final meta = _stringMap(envelope['meta']);
      throw AlkokhMobileException(
        code:
            first['code'] as String? ?? meta['code'] as String? ?? 'Error',
        message: first['message'] as String? ?? 'Request failed.',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AlkokhMobileException(
        code: 'HTTP_${response.statusCode}',
        message: response.reasonPhrase ?? 'HTTP request failed.',
        statusCode: response.statusCode,
      );
    }

    if (envelope['ok'] == true) {
      return _stringMap(envelope['data']);
    }

    if (envelope.containsKey('data')) {
      return _stringMap(envelope['data']);
    }

    return envelope;
  }

  String _validatePhone(String phone) {
    final value = phone.trim().replaceAll(' ', '').replaceAll('-', '');
    final local = RegExp(r'^07\d{9}$');
    final international = RegExp(r'^9647\d{9}$');
    if (local.hasMatch(value)) return value;
    if (international.hasMatch(value)) return '0${value.substring(3)}';
    throw AlkokhValidationException(
      'Invalid phone. Use 07XXXXXXXXX or 9647XXXXXXXXX.',
    );
  }

  String _validateOtp(String otp) {
    final value = otp.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(value)) {
      throw AlkokhValidationException('OTP must be six digits.');
    }
    return value;
  }

  String _validatePassword(String password) {
    if (password.length < 6 || password.length > 50) {
      throw AlkokhValidationException('Password must be 6 to 50 characters.');
    }
    return password;
  }

  String _validateFullName(String fullName) {
    final value = fullName.trim();
    if (value.isEmpty || value.length > 100) {
      throw AlkokhValidationException('Full name must be 1 to 100 characters.');
    }
    return value;
  }

  String _validatePetName(String name) {
    final value = name.trim();
    if (value.isEmpty || value.length > 140) {
      throw AlkokhValidationException('Pet name must be 1 to 140 characters.');
    }
    return value;
  }

  int _validateRating(int rating) {
    if (rating < 1 || rating > 5) {
      throw AlkokhValidationException('Rating must be between 1 and 5.');
    }
    return rating;
  }

  String _validateRequiredText(String value, String label) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw AlkokhValidationException('$label is required.');
    }
    return trimmed;
  }

  Future<String> _resolveGuardianId(String? guardianId) async {
    if (guardianId != null && guardianId.trim().isNotEmpty) {
      return guardianId.trim();
    }
    final profile = await getMe();
    final guardian = profile.guardianId;
    if (guardian == null || guardian.trim().isEmpty) {
      throw AlkokhValidationException(
        'Guardian is required to book an appointment.',
      );
    }
    return guardian.trim();
  }

  String _formatDate(DateTime value) {
    return [
      value.year.toString().padLeft(4, '0'),
      value.month.toString().padLeft(2, '0'),
      value.day.toString().padLeft(2, '0'),
    ].join('-');
  }

  String _formatDateTime(DateTime value) {
    final date = _formatDate(value);
    final time = [
      value.hour.toString().padLeft(2, '0'),
      value.minute.toString().padLeft(2, '0'),
      value.second.toString().padLeft(2, '0'),
    ].join(':');
    return '$date $time';
  }

  String _normalizePaymentMethod(String paymentMethod) {
    final key = paymentMethod
        .trim()
        .toLowerCase()
        .replaceAll('-', ' ')
        .replaceAll('_', ' ');
    if (key.isEmpty ||
        key == 'cash' ||
        key == 'cod' ||
        key == 'cash on delivery') {
      return 'Cash on Delivery';
    }
    throw AlkokhValidationException(
      'Only Cash on Delivery is currently supported.',
    );
  }

  Map<String, Object?> _petBody({
    String? name,
    String? species,
    String? type,
    String? breed,
    String? birthDate,
    String? registrationDate,
    String? color,
    String? gender,
    num? weight,
    num? height,
    String? bloodType,
    String? play,
    String? activityExercise,
    String? foodBrand,
    String? foodType,
    String? description,
    String? note,
  }) {
    return <String, Object?>{
      if (name != null) 'name': name,
      if (species != null) 'species': species,
      if (type != null) 'type': type,
      if (breed != null) 'breed': breed,
      if (birthDate != null) 'birth_date': birthDate,
      if (registrationDate != null) 'registration_date': registrationDate,
      if (color != null) 'color': color,
      if (gender != null) 'gender': gender,
      if (weight != null) 'weight': weight,
      if (height != null) 'height': height,
      if (bloodType != null) 'blood_type': bloodType,
      if (play != null) 'play': play,
      if (activityExercise != null) 'activity_exercise': activityExercise,
      if (foodBrand != null) 'food_brand': foodBrand,
      if (foodType != null) 'food_type': foodType,
      if (description != null) 'description': description,
      if (note != null) 'note': note,
    };
  }

  Map<String, Object?> _medicalRecordBody(
    String petId, {
    String? recordType,
    String? name,
    String? vaccineName,
    String? vaccineType,
    String? medication,
    String? medicationName,
    String? dose,
    String? batchNo,
    String? administeredOn,
    String? nextDueDate,
    bool? reminderEnabled,
    String? notes,
  }) {
    return <String, Object?>{
      'pet': petId,
      if (recordType != null && recordType.isNotEmpty)
        'record_type': recordType,
      if (name != null) 'name': name,
      if (vaccineName != null) 'vaccine_name': vaccineName,
      if (vaccineType != null) 'vaccine_type': vaccineType,
      if (medication != null) 'medication': medication,
      if (medicationName != null) 'medication_name': medicationName,
      if (dose != null) 'dose': dose,
      if (batchNo != null) 'batch_no': batchNo,
      if (administeredOn != null) 'administered_on': administeredOn,
      if (nextDueDate != null) 'next_due_date': nextDueDate,
      if (reminderEnabled != null) 'reminder_enabled': reminderEnabled ? 1 : 0,
      if (notes != null) 'notes': notes,
    };
  }

  Map<String, Object?> _addressBody({
    String? title,
    String? addressLine1,
    String? addressLine2,
    String? city,
    String? area,
    String? state,
    String? country,
    String? pincode,
    String? phone,
    String? emailId,
    String? notes,
    double? latitude,
    double? longitude,
    bool clearCoordinates = false,
  }) {
    if (clearCoordinates && (latitude != null || longitude != null)) {
      throw AlkokhValidationException(
        'Pass either a coordinate pair or clearCoordinates, not both.',
      );
    }
    if ((latitude == null) != (longitude == null)) {
      throw AlkokhValidationException(
        'Latitude and longitude must be sent together.',
      );
    }
    if (latitude != null && (latitude < -90 || latitude > 90)) {
      throw AlkokhValidationException(
        'Latitude must be a number between -90 and 90.',
      );
    }
    if (longitude != null && (longitude < -180 || longitude > 180)) {
      throw AlkokhValidationException(
        'Longitude must be a number between -180 and 180.',
      );
    }
    return <String, Object?>{
      if (title != null) 'title': title,
      if (addressLine1 != null) 'address_line1': addressLine1,
      if (addressLine2 != null) 'address_line2': addressLine2,
      if (city != null) 'city': city,
      if (area != null) 'area': area,
      if (state != null) 'state': state,
      if (country != null) 'country': country,
      if (pincode != null) 'pincode': pincode,
      if (phone != null) 'phone': phone,
      if (emailId != null) 'email_id': emailId,
      // Maps to Address.custom_notes on the backend. A delivery instruction for whoever
      // makes the drop - not part of the printed address, which is what address_line2 is.
      if (notes != null) 'notes': notes,
      // The delivery map pin, Address.custom_latitude / custom_longitude. The backend
      // validates the pair the same way this does and refuses a lone coordinate; two
      // empty strings clear it, which is what clearCoordinates sends.
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (clearCoordinates) 'latitude': '',
      if (clearCoordinates) 'longitude': '',
    };
  }
}

Map<String, Object?> _stringMap(Object? value) {
  if (value is Map<String, Object?>) return value;
  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }
  return {};
}

List<Map<String, Object?>> _listOfMaps(Object? value) {
  if (value is! List) return const [];
  return value.map(_stringMap).toList();
}
