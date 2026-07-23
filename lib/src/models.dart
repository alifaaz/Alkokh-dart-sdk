class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    required this.tokenType,
    required this.expiresAt,
    this.user,
    this.fullName,
  });

  final String accessToken;
  final String? refreshToken;
  final int expiresIn;
  final String tokenType;
  final DateTime expiresAt;
  final String? user;
  final String? fullName;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  bool expiresWithin(Duration duration) {
    return DateTime.now().add(duration).isAfter(expiresAt);
  }

  AuthSession copyWith({
    String? accessToken,
    Object? refreshToken = _sentinel,
    int? expiresIn,
    String? tokenType,
    DateTime? expiresAt,
    Object? user = _sentinel,
    Object? fullName = _sentinel,
  }) {
    return AuthSession(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: identical(refreshToken, _sentinel)
          ? this.refreshToken
          : refreshToken as String?,
      expiresIn: expiresIn ?? this.expiresIn,
      tokenType: tokenType ?? this.tokenType,
      expiresAt: expiresAt ?? this.expiresAt,
      user: identical(user, _sentinel) ? this.user : user as String?,
      fullName: identical(fullName, _sentinel)
          ? this.fullName
          : fullName as String?,
    );
  }

  static AuthSession fromJson(
    Map<String, Object?> json, {
    String? existingRefreshToken,
    DateTime? receivedAt,
  }) {
    final accessToken = json['access_token'];
    if (accessToken is! String || accessToken.isEmpty) {
      throw FormatException('Missing access_token');
    }

    final expiresIn = _readInt(json['expires_in']) ?? 3600;
    final refreshToken =
        json['refresh_token'] is String &&
            (json['refresh_token']! as String).isNotEmpty
        ? json['refresh_token']! as String
        : existingRefreshToken;
    final baseTime = receivedAt ?? DateTime.now();

    return AuthSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresIn: expiresIn,
      tokenType: json['token_type'] as String? ?? 'Bearer',
      expiresAt: baseTime.add(Duration(seconds: expiresIn)),
      user: json['user'] as String?,
      fullName: json['full_name'] as String?,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'expires_in': expiresIn,
      'token_type': tokenType,
      'expires_at': expiresAt.toIso8601String(),
      'user': user,
      'full_name': fullName,
    };
  }

  static AuthSession fromStoredJson(Map<String, Object?> json) {
    final accessToken = json['access_token'];
    if (accessToken is! String || accessToken.isEmpty) {
      throw FormatException('Missing access_token');
    }

    return AuthSession(
      accessToken: accessToken,
      refreshToken: json['refresh_token'] as String?,
      expiresIn: _readInt(json['expires_in']) ?? 3600,
      tokenType: json['token_type'] as String? ?? 'Bearer',
      expiresAt: DateTime.parse(json['expires_at'] as String),
      user: json['user'] as String?,
      fullName: json['full_name'] as String?,
    );
  }
}

class MobileMessage {
  const MobileMessage(this.message);

  final String message;

  static MobileMessage fromJson(Map<String, Object?> json) {
    return MobileMessage(json['message'] as String? ?? '');
  }
}

class AppointmentSlot {
  const AppointmentSlot({
    required this.start,
    required this.end,
    required this.raw,
    this.doctor,
    this.practitioner,
    this.room,
    this.doctorName,
  });

  final String start;
  final String end;
  final String? doctor;
  final String? practitioner;
  final String? room;
  final String? doctorName;
  final Map<String, Object?> raw;

  static AppointmentSlot fromJson(Map<String, Object?> json) {
    return AppointmentSlot(
      start: json['start']?.toString() ?? '',
      end: json['end']?.toString() ?? '',
      doctor: json['doctor'] as String?,
      practitioner: json['practitioner'] as String?,
      room: json['room'] as String?,
      doctorName: json['doctor_name'] as String?,
      raw: Map<String, Object?>.from(json),
    );
  }
}

class MobileAppointment {
  const MobileAppointment({
    required this.id,
    required this.status,
    required this.raw,
    this.scheduledTime,
    this.pet,
    this.petName,
    this.guardian,
    this.guardianName,
    this.customer,
    this.doctor,
    this.doctorName,
    this.practitioner,
    this.room,
    this.durationMinutes,
    this.appointmentType,
    this.customerDetails,
  });

  final String id;
  final String status;
  final String? scheduledTime;
  final String? pet;
  final String? petName;
  final String? guardian;
  final String? guardianName;
  final String? customer;
  final String? doctor;
  final String? doctorName;
  final String? practitioner;
  final String? room;
  final int? durationMinutes;
  final String? appointmentType;
  final String? customerDetails;
  final Map<String, Object?> raw;

  static MobileAppointment fromJson(Map<String, Object?> json) {
    final doctor =
        json['doctor'] as String? ?? json['custom_doctor'] as String?;
    return MobileAppointment(
      id: (json['id'] ?? json['name'] ?? '') as String,
      status: json['status'] as String? ?? '',
      scheduledTime:
          (json['scheduled_time'] ?? json['start'] ?? json['appointment_time'])
              ?.toString(),
      pet: json['pet'] as String? ?? json['custom_pet'] as String?,
      petName: json['pet_name'] as String?,
      guardian:
          json['guardian'] as String? ?? json['custom_guardian'] as String?,
      guardianName: json['guardian_name'] as String?,
      customer:
          json['customer'] as String? ?? json['custom_customer'] as String?,
      doctor: doctor,
      doctorName: json['doctor_name'] as String?,
      practitioner: json['practitioner'] as String? ?? doctor,
      room: json['room'] as String? ?? json['custom_room'] as String?,
      durationMinutes:
          _readInt(json['duration_minutes']) ??
          _readInt(json['custom_duration_minutes']),
      appointmentType:
          json['appointment_type'] as String? ??
          json['custom_appointment_type'] as String?,
      customerDetails: json['customer_details'] as String?,
      raw: Map<String, Object?>.from(json),
    );
  }
}

class CareServiceTemplateSummary {
  const CareServiceTemplateSummary({
    required this.id,
    required this.raw,
    this.serviceName,
    this.arabicName,
    this.frequency,
    this.itemCode,
    this.priceList,
    this.specimen,
    this.estimatedTurnaround,
    this.modality,
    this.bodyPart,
    this.serviceArea,
    this.animalSpecies,
    this.categoryId,
    this.defaultPrice,
    this.description,
    this.disabled,
  });

  final String id;
  final String? serviceName;
  final String? arabicName;
  final String? frequency;
  final String? itemCode;
  final String? priceList;
  final String? specimen;
  final String? estimatedTurnaround;
  final String? modality;
  final String? bodyPart;
  final String? serviceArea;
  final String? animalSpecies;
  final String? categoryId;
  final num? defaultPrice;
  final String? description;
  final bool? disabled;
  final Map<String, Object?> raw;

  static CareServiceTemplateSummary fromJson(Map<String, Object?> json) {
    return CareServiceTemplateSummary(
      id: json['name'] as String? ?? '',
      serviceName: json['service_name'] as String?,
      arabicName: json['arabic_name'] as String?,
      frequency: json['frequency'] as String?,
      itemCode: json['item_code'] as String?,
      priceList: json['price_list'] as String?,
      specimen: json['specimen'] as String?,
      estimatedTurnaround: json['estimated_turnaround'] as String?,
      modality: json['modality'] as String?,
      bodyPart: json['body_part'] as String?,
      serviceArea: json['service_area'] as String?,
      animalSpecies: json['animal_species'] as String?,
      categoryId: json['category_id'] as String?,
      defaultPrice: _readNum(json['default_price']),
      description: json['description'] as String?,
      disabled: _readBool(json['disabled']),
      raw: Map<String, Object?>.from(json),
    );
  }
}

class CareServiceCategorySummary {
  const CareServiceCategorySummary({
    required this.id,
    required this.raw,
    this.categoryName,
    this.arabicName,
    this.description,
    this.active,
  });

  final String id;
  final String? categoryName;
  final String? arabicName;
  final String? description;
  final bool? active;
  final Map<String, Object?> raw;

  static CareServiceCategorySummary fromJson(Map<String, Object?> json) {
    return CareServiceCategorySummary(
      id: json['name'] as String? ?? '',
      categoryName: json['category_name'] as String?,
      arabicName: json['arabic_name'] as String?,
      description: json['description'] as String?,
      active: _readBool(json['active']),
      raw: Map<String, Object?>.from(json),
    );
  }
}

class CareServiceOptionSummary {
  const CareServiceOptionSummary({
    required this.id,
    required this.raw,
    this.optionLabel,
    this.arOptionLabel,
    this.animalSpecies,
    this.animalType,
    this.sizeWeightLabel,
    this.minWeight,
    this.maxWeight,
    this.itemCode,
    this.defaultRate,
    this.serviceTitle,
  });

  final String id;
  final String? optionLabel;
  final String? arOptionLabel;
  final String? animalSpecies;
  final String? animalType;
  final String? sizeWeightLabel;
  final num? minWeight;
  final num? maxWeight;
  final String? itemCode;
  final num? defaultRate;
  final String? serviceTitle;
  final Map<String, Object?> raw;

  static CareServiceOptionSummary fromJson(Map<String, Object?> json) {
    return CareServiceOptionSummary(
      id: json['name'] as String? ?? '',
      optionLabel: json['option_label'] as String?,
      arOptionLabel: json['ar_option_label'] as String?,
      animalSpecies: json['animal_species'] as String?,
      animalType: json['animal_type'] as String?,
      sizeWeightLabel: json['size_weight_label'] as String?,
      minWeight: _readNum(json['min_weight']),
      maxWeight: _readNum(json['max_weight']),
      itemCode: json['item_code'] as String?,
      defaultRate: _readNum(json['default_rate']),
      serviceTitle: json['service_title'] as String?,
      raw: Map<String, Object?>.from(json),
    );
  }
}

class MobilePetCareService {
  const MobilePetCareService({
    required this.id,
    required this.status,
    required this.raw,
    this.serviceName,
    this.petId,
    this.petName,
    this.guardianId,
    this.guardianName,
    this.category,
    this.categoryName,
    this.categoryArabicName,
    this.careServiceId,
    this.serviceOption,
    this.itemCode,
    this.price,
    this.doctor,
    this.doctorName,
    this.provider,
    this.providerName,
    this.visit,
    this.sourceDoctype,
    this.sourceName,
    this.orderId,
    this.startDate,
    this.endDate,
    this.dueDate,
    this.weight,
    this.size,
    this.description,
    this.template,
    this.categoryDetails,
    this.optionDetails,
  });

  final String id;
  final String status;
  final String? serviceName;
  final String? petId;
  final String? petName;
  final String? guardianId;
  final String? guardianName;
  final String? category;
  final String? categoryName;
  final String? categoryArabicName;
  final String? careServiceId;
  final String? serviceOption;
  final String? itemCode;
  final num? price;
  final String? doctor;
  final String? doctorName;
  final String? provider;
  final String? providerName;
  final String? visit;
  final String? sourceDoctype;
  final String? sourceName;
  final String? orderId;
  final String? startDate;
  final String? endDate;
  final String? dueDate;
  final num? weight;
  final String? size;
  final String? description;
  final CareServiceTemplateSummary? template;
  final CareServiceCategorySummary? categoryDetails;
  final CareServiceOptionSummary? optionDetails;
  final Map<String, Object?> raw;

  static MobilePetCareService fromJson(Map<String, Object?> json) {
    final template = _stringMap(json['care_service']);
    final categoryDetails = _stringMap(json['category_details']);
    final optionDetails = _stringMap(json['service_option_details']);
    return MobilePetCareService(
      id: (json['service_id'] ?? json['name'] ?? '') as String,
      status: json['status'] as String? ?? '',
      serviceName:
          json['service_name'] as String? ??
          json['pet_service_name'] as String?,
      petId: json['pet_id'] as String?,
      petName: json['pet_name'] as String?,
      guardianId: json['guardian_id'] as String?,
      guardianName: json['guardian_name'] as String?,
      category: json['category'] as String?,
      categoryName: json['category_name'] as String?,
      categoryArabicName: json['category_arabic_name'] as String?,
      careServiceId: json['care_service_id'] as String?,
      serviceOption: json['service_option'] as String?,
      itemCode: json['item_code'] as String?,
      price: _readNum(json['price']),
      doctor: json['doctor'] as String?,
      doctorName: json['doctor_name'] as String?,
      provider: json['provider'] as String?,
      providerName: json['provider_name'] as String?,
      visit: json['visit'] as String?,
      sourceDoctype: json['source_doctype'] as String?,
      sourceName: json['source_name'] as String?,
      orderId: json['order_id'] as String?,
      startDate: json['start_date']?.toString(),
      endDate: json['end_date']?.toString(),
      dueDate: json['due_date']?.toString(),
      weight: _readNum(json['weight']),
      size: json['size'] as String?,
      description: json['description'] as String?,
      template: template.isEmpty
          ? null
          : CareServiceTemplateSummary.fromJson(template),
      categoryDetails: categoryDetails.isEmpty
          ? null
          : CareServiceCategorySummary.fromJson(categoryDetails),
      optionDetails: optionDetails.isEmpty
          ? null
          : CareServiceOptionSummary.fromJson(optionDetails),
      raw: Map<String, Object?>.from(json),
    );
  }
}

class ResetToken {
  const ResetToken(this.value);

  final String value;

  static ResetToken fromJson(Map<String, Object?> json) {
    final token = json['reset_token'];
    if (token is! String || token.isEmpty) {
      throw FormatException('Missing reset_token');
    }
    return ResetToken(token);
  }
}

class PagedResult<T> {
  const PagedResult({
    required this.items,
    required this.hasMore,
    this.nextCursor,
  });

  final List<T> items;
  final bool hasMore;
  final String? nextCursor;
}

class MobileOrder {
  const MobileOrder({
    required this.id,
    required this.status,
    required this.statusKey,
    required this.grandTotal,
    required this.raw,
    this.erpStatus,
    this.paymentMethod,
    this.paymentStatus,
    this.currency,
    this.customer,
    this.customerName,
    this.delivery,
    this.items = const [],
    this.timeline = const [],
  });

  final String id;
  final String status;
  final String statusKey;
  final num grandTotal;
  final String? erpStatus;
  final String? paymentMethod;
  final String? paymentStatus;
  final String? currency;
  final String? customer;
  final String? customerName;
  final MobileOrderDelivery? delivery;
  final List<MobileOrderItem> items;
  final List<MobileOrderTimelineStep> timeline;
  final Map<String, Object?> raw;

  static MobileOrder fromJson(Map<String, Object?> json) {
    return MobileOrder(
      id: (json['id'] ?? json['order'] ?? '') as String,
      status: json['status'] as String? ?? '',
      statusKey: json['status_key'] as String? ?? '',
      grandTotal: _readNum(json['grand_total']) ?? 0,
      erpStatus: json['erp_status'] as String?,
      paymentMethod: json['payment_method'] as String?,
      paymentStatus: json['payment_status'] as String?,
      currency: json['currency'] as String?,
      customer: json['customer'] as String?,
      customerName: json['customer_name'] as String?,
      delivery: json['delivery'] is Map
          ? MobileOrderDelivery.fromJson(_stringMap(json['delivery']))
          : null,
      items: _listOfMaps(json['items']).map(MobileOrderItem.fromJson).toList(),
      timeline: _listOfMaps(
        json['timeline'],
      ).map(MobileOrderTimelineStep.fromJson).toList(),
      raw: Map<String, Object?>.from(json),
    );
  }
}

class MobileOrderDelivery {
  const MobileOrderDelivery({
    this.driver,
    this.latitude,
    this.longitude,
    this.fee,
  });

  final String? driver;
  final num? latitude;
  final num? longitude;
  final num? fee;

  static MobileOrderDelivery fromJson(Map<String, Object?> json) {
    return MobileOrderDelivery(
      driver: json['driver'] as String?,
      latitude: _readNum(json['latitude']),
      longitude: _readNum(json['longitude']),
      fee: _readNum(json['fee']),
    );
  }
}

class MobileOrderItem {
  const MobileOrderItem({
    required this.itemCode,
    required this.qty,
    this.id,
    this.itemName,
    this.description,
    this.rate,
    this.amount,
    this.availableQty,
    this.image,
    this.warehouse,
  });

  final String? id;
  final String itemCode;
  final String? itemName;
  final String? description;
  final num qty;
  final num? rate;
  final num? amount;
  final num? availableQty;
  final String? image;
  final String? warehouse;

  static MobileOrderItem fromJson(Map<String, Object?> json) {
    return MobileOrderItem(
      id: json['id'] as String?,
      itemCode: json['item_code'] as String? ?? '',
      itemName: json['item_name'] as String?,
      description: json['description'] as String?,
      qty: _readNum(json['qty']) ?? 0,
      rate: _readNum(json['rate']),
      amount: _readNum(json['amount']),
      availableQty: _readNum(json['available_qty']),
      image: json['image'] as String?,
      warehouse: json['warehouse'] as String?,
    );
  }

  Map<String, Object?> toPlaceOrderJson() {
    return {'item_code': itemCode, 'qty': qty};
  }
}

class MobileOrderTimelineStep {
  const MobileOrderTimelineStep({
    required this.status,
    required this.statusKey,
    required this.state,
  });

  final String status;
  final String statusKey;
  final String state;

  static MobileOrderTimelineStep fromJson(Map<String, Object?> json) {
    return MobileOrderTimelineStep(
      status: json['status'] as String? ?? '',
      statusKey: json['status_key'] as String? ?? '',
      state: json['state'] as String? ?? '',
    );
  }
}

class ReorderDraft {
  const ReorderDraft({
    required this.sourceOrder,
    required this.items,
    this.message,
  });

  final String sourceOrder;
  final List<MobileOrderItem> items;
  final String? message;

  static ReorderDraft fromJson(Map<String, Object?> json) {
    return ReorderDraft(
      sourceOrder: json['source_order'] as String? ?? '',
      items: _listOfMaps(json['items']).map(MobileOrderItem.fromJson).toList(),
      message: json['message'] as String?,
    );
  }
}

class OrderQuote {
  const OrderQuote({
    required this.items,
    required this.issues,
    required this.canPlaceOrder,
    required this.subtotal,
    required this.deliveryFee,
    required this.discountAmount,
    required this.grandTotal,
    required this.raw,
    this.paymentMethod,
    this.currency,
    this.couponCode,
  });

  final List<MobileOrderItem> items;
  final List<OrderQuoteIssue> issues;
  final bool canPlaceOrder;
  final num subtotal;
  final num deliveryFee;
  final num discountAmount;
  final num grandTotal;
  final String? paymentMethod;
  final String? currency;
  final String? couponCode;
  final Map<String, Object?> raw;

  static OrderQuote fromJson(Map<String, Object?> json) {
    return OrderQuote(
      items: _listOfMaps(json['items']).map(MobileOrderItem.fromJson).toList(),
      issues: _listOfMaps(
        json['issues'],
      ).map(OrderQuoteIssue.fromJson).toList(),
      canPlaceOrder: json['can_place_order'] == true,
      subtotal: _readNum(json['subtotal']) ?? 0,
      deliveryFee: _readNum(json['delivery_fee']) ?? 0,
      discountAmount: _readNum(json['discount_amount']) ?? 0,
      grandTotal: _readNum(json['grand_total']) ?? 0,
      paymentMethod: json['payment_method'] as String?,
      currency: json['currency'] as String?,
      couponCode: json['coupon_code'] as String?,
      raw: Map<String, Object?>.from(json),
    );
  }
}

class OrderQuoteIssue {
  const OrderQuoteIssue({
    required this.code,
    required this.message,
    required this.raw,
    this.itemCode,
  });

  final String code;
  final String message;
  final String? itemCode;
  final Map<String, Object?> raw;

  static OrderQuoteIssue fromJson(Map<String, Object?> json) {
    return OrderQuoteIssue(
      code: json['code'] as String? ?? '',
      message: json['message'] as String? ?? '',
      itemCode: json['item_code'] as String?,
      raw: Map<String, Object?>.from(json),
    );
  }
}

class MobileAppConfig {
  const MobileAppConfig({
    required this.currency,
    required this.supportedLocales,
    required this.defaultLocale,
    required this.featureFlags,
    required this.raw,
  });

  final String currency;
  final List<String> supportedLocales;
  final String defaultLocale;
  final Map<String, bool> featureFlags;
  final Map<String, Object?> raw;

  static MobileAppConfig fromJson(Map<String, Object?> json) {
    return MobileAppConfig(
      currency: json['currency'] as String? ?? 'IQD',
      supportedLocales: (json['supported_locales'] as List? ?? const [])
          .map((value) => value.toString())
          .toList(),
      defaultLocale: json['default_locale'] as String? ?? 'en',
      featureFlags: _stringMap(
        json['feature_flags'],
      ).map((key, value) => MapEntry(key, value == true)),
      raw: Map<String, Object?>.from(json),
    );
  }
}

class SupportContact {
  const SupportContact({
    this.name,
    this.phone,
    this.email,
    this.whatsapp,
    required this.raw,
  });

  final String? name;
  final String? phone;
  final String? email;
  final String? whatsapp;
  final Map<String, Object?> raw;

  static SupportContact fromJson(Map<String, Object?> json) {
    return SupportContact(
      name: json['name'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      whatsapp: json['whatsapp'] as String?,
      raw: Map<String, Object?>.from(json),
    );
  }
}

class StaticContent {
  const StaticContent({
    required this.key,
    required this.title,
    required this.body,
  });

  final String key;
  final String title;
  final String body;

  static StaticContent fromJson(Map<String, Object?> json) {
    return StaticContent(
      key: json['key'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
    );
  }
}

class MobileProfile {
  const MobileProfile({
    this.user,
    this.guardianId,
    this.customerId,
    this.fullName,
    this.phone,
    this.emailId,
    this.city,
    this.country,
    this.addressLine1,
    this.guardianImage,
    required this.raw,
  });

  final String? user;
  final String? guardianId;
  final String? customerId;
  final String? fullName;
  final String? phone;
  final String? emailId;
  final String? city;
  final String? country;
  final String? addressLine1;
  final String? guardianImage;
  final Map<String, Object?> raw;

  static MobileProfile fromJson(Map<String, Object?> json) {
    return MobileProfile(
      user: json['user'] as String?,
      guardianId: json['guardian_id'] as String?,
      customerId: json['customer_id'] as String?,
      fullName: json['full_name'] as String?,
      phone: json['phone'] as String?,
      emailId: json['email_id'] as String?,
      city: json['city'] as String?,
      country: json['country'] as String?,
      addressLine1: json['address_line1'] as String?,
      guardianImage: json['guardian_image'] as String?,
      raw: Map<String, Object?>.from(json),
    );
  }
}

class MobileFileAttachment {
  const MobileFileAttachment({
    required this.id,
    required this.fileUrl,
    required this.raw,
    this.fileName,
    this.isPrivate = false,
    this.isDefault = false,
    this.duplicate = false,
  });

  final String id;
  final String fileUrl;
  final String? fileName;
  final bool isPrivate;
  final bool isDefault;
  final bool duplicate;
  final Map<String, Object?> raw;

  static MobileFileAttachment fromJson(Map<String, Object?> json) {
    return MobileFileAttachment(
      id: (json['id'] ?? json['name'] ?? '') as String,
      fileUrl: json['file_url'] as String? ?? '',
      fileName: json['file_name'] as String?,
      isPrivate: json['is_private'] == true,
      isDefault: json['is_default'] == true,
      duplicate: json['duplicate'] == true,
      raw: Map<String, Object?>.from(json),
    );
  }
}

class AvatarUploadResult {
  const AvatarUploadResult({
    required this.file,
    required this.profile,
    required this.raw,
  });

  final MobileFileAttachment file;
  final MobileProfile profile;
  final Map<String, Object?> raw;

  static AvatarUploadResult fromJson(Map<String, Object?> json) {
    return AvatarUploadResult(
      file: MobileFileAttachment.fromJson(_stringMap(json['file'])),
      profile: MobileProfile.fromJson(_stringMap(json['profile'])),
      raw: Map<String, Object?>.from(json),
    );
  }
}

class PhoneChangeStart {
  const PhoneChangeStart({required this.message, required this.newPhone});

  final String message;
  final String newPhone;

  static PhoneChangeStart fromJson(Map<String, Object?> json) {
    return PhoneChangeStart(
      message: json['message'] as String? ?? '',
      newPhone: json['new_phone'] as String? ?? '',
    );
  }
}

class MobileDevice {
  const MobileDevice({
    required this.id,
    required this.fcmToken,
    required this.platform,
    required this.disabled,
    required this.raw,
    this.deviceId,
    this.lastSeenAt,
  });

  final String id;
  final String fcmToken;
  final String platform;
  final String? deviceId;
  final String? lastSeenAt;
  final bool disabled;
  final Map<String, Object?> raw;

  static MobileDevice fromJson(Map<String, Object?> json) {
    return MobileDevice(
      id: json['id'] as String? ?? '',
      fcmToken: json['fcm_token'] as String? ?? '',
      platform: json['platform'] as String? ?? 'unknown',
      deviceId: json['device_id'] as String?,
      lastSeenAt: json['last_seen_at']?.toString(),
      disabled: json['disabled'] == true,
      raw: Map<String, Object?>.from(json),
    );
  }
}

class MobileDeviceState {
  const MobileDeviceState({
    required this.fcmToken,
    required this.disabled,
    required this.raw,
  });

  final String fcmToken;
  final bool disabled;
  final Map<String, Object?> raw;

  static MobileDeviceState fromJson(Map<String, Object?> json) {
    return MobileDeviceState(
      fcmToken: json['fcm_token'] as String? ?? '',
      disabled: json['disabled'] == true,
      raw: Map<String, Object?>.from(json),
    );
  }
}

class MobileAddress {
  const MobileAddress({
    required this.id,
    required this.raw,
    this.title,
    this.type,
    this.addressLine1,
    this.addressLine2,
    this.city,
    this.county,
    this.state,
    this.country,
    this.pincode,
    this.phone,
    this.emailId,
    this.isDefault = false,
    this.isShippingAddress = false,
    this.isPrimaryAddress = false,
    this.isDisabled = false,
    this.display,
  });

  final String id;
  final String? title;
  final String? type;
  final String? addressLine1;
  final String? addressLine2;
  final String? city;
  final String? county;
  final String? state;
  final String? country;
  final String? pincode;
  final String? phone;
  final String? emailId;
  final bool isDefault;
  final bool isShippingAddress;
  final bool isPrimaryAddress;
  final bool isDisabled;
  final String? display;
  final Map<String, Object?> raw;

  static MobileAddress fromJson(Map<String, Object?> json) {
    return MobileAddress(
      id: (json['id'] ?? json['address_id'] ?? '') as String,
      title: json['title'] as String?,
      type: json['type'] as String?,
      addressLine1: json['address_line1'] as String?,
      addressLine2: json['address_line2'] as String?,
      city: json['city'] as String?,
      county: json['county'] as String?,
      state: json['state'] as String?,
      country: json['country'] as String?,
      pincode: json['pincode'] as String?,
      phone: json['phone'] as String?,
      emailId: json['email_id'] as String?,
      isDefault: json['is_default'] == true,
      isShippingAddress: json['is_shipping_address'] == true,
      isPrimaryAddress: json['is_primary_address'] == true,
      isDisabled: json['is_disabled'] == true,
      display: json['display'] as String?,
      raw: Map<String, Object?>.from(json),
    );
  }
}

class SupportedCity {
  const SupportedCity({required this.id, required this.name, this.country});

  final String id;
  final String name;
  final String? country;

  static SupportedCity fromJson(Map<String, Object?> json) {
    return SupportedCity(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      country: json['country'] as String?,
    );
  }
}

class ReverseGeocodeResult {
  const ReverseGeocodeResult({
    this.latitude,
    this.longitude,
    this.country,
    this.city,
    this.addressLine1,
    this.provider,
    required this.raw,
  });

  final Object? latitude;
  final Object? longitude;
  final String? country;
  final String? city;
  final String? addressLine1;
  final String? provider;
  final Map<String, Object?> raw;

  static ReverseGeocodeResult fromJson(Map<String, Object?> json) {
    return ReverseGeocodeResult(
      latitude: json['latitude'],
      longitude: json['longitude'],
      country: json['country'] as String?,
      city: json['city'] as String?,
      addressLine1: json['address_line1'] as String?,
      provider: json['provider'] as String?,
      raw: Map<String, Object?>.from(json),
    );
  }
}

class CatalogProduct {
  const CatalogProduct({
    required this.id,
    required this.name,
    required this.effectivePrice,
    required this.inStock,
    required this.raw,
    this.sku,
    this.description,
    this.image,
    this.price,
    this.discountedPrice,
    this.originalPrice,
    this.currency,
    this.unit,
    this.qty,
    this.category,
    this.brand,
    this.itemCode,
    this.reviewSummary,
    this.rating,
    this.ratingCount,
    this.filter,
    this.tags = const [],
  });

  final String id;
  final String name;
  final String? sku;
  final String? description;
  final String? image;
  final num? price;
  final num? discountedPrice;
  final num? originalPrice;
  final num effectivePrice;
  final String? currency;
  final String? unit;
  final bool inStock;
  final num? qty;
  final CatalogCategory? category;
  final CatalogBrand? brand;
  final String? itemCode;
  final ProductReviewSummary? reviewSummary;
  final num? rating;
  final int? ratingCount;
  final String? filter;
  final List<String> tags;
  final Map<String, Object?> raw;

  static CatalogProduct fromJson(Map<String, Object?> json) {
    return CatalogProduct(
      id: (json['id'] ?? json['product_id'] ?? '') as String,
      name: json['name'] as String? ?? '',
      sku: json['sku'] as String?,
      description: json['description'] as String?,
      image: json['image'] as String?,
      price: _readNum(json['price']),
      discountedPrice: _readNum(json['discounted_price']),
      originalPrice: _readNum(json['original_price']),
      effectivePrice: _readNum(json['effective_price']) ?? 0,
      currency: json['currency'] as String?,
      unit: json['unit'] as String?,
      inStock: json['in_stock'] == true,
      qty: _readNum(json['qty']),
      category: json['category'] is Map
          ? CatalogCategory.fromJson(_stringMap(json['category']))
          : null,
      brand: json['brand'] is Map
          ? CatalogBrand.fromJson(_stringMap(json['brand']))
          : null,
      itemCode: json['item_code'] as String?,
      reviewSummary: json['review_summary'] is Map
          ? ProductReviewSummary.fromJson(_stringMap(json['review_summary']))
          : null,
      rating: _readNum(json['rating']),
      ratingCount: _readInt(json['rating_count']),
      filter: json['filter'] as String?,
      tags: (json['tags'] as List? ?? const [])
          .map((value) => value.toString())
          .toList(),
      raw: Map<String, Object?>.from(json),
    );
  }
}

class MobileFavorite {
  const MobileFavorite({
    required this.id,
    required this.productId,
    required this.isFavorite,
    required this.raw,
    this.product,
    this.createdAt,
  });

  final String id;
  final String productId;
  final bool isFavorite;
  final CatalogProduct? product;
  final String? createdAt;
  final Map<String, Object?> raw;

  static MobileFavorite fromJson(Map<String, Object?> json) {
    return MobileFavorite(
      id: (json['id'] ?? json['favorite_id'] ?? '') as String,
      productId: json['product_id'] as String? ?? '',
      isFavorite: json['is_favorite'] != false,
      product: json['product'] is Map
          ? CatalogProduct.fromJson(_stringMap(json['product']))
          : null,
      createdAt: json['created_at'] as String?,
      raw: Map<String, Object?>.from(json),
    );
  }
}

class MobileFavoriteState {
  const MobileFavoriteState({
    required this.productId,
    required this.isFavorite,
    required this.raw,
    this.favorite,
    this.product,
  });

  final String productId;
  final bool isFavorite;
  final MobileFavorite? favorite;
  final CatalogProduct? product;
  final Map<String, Object?> raw;

  static MobileFavoriteState fromJson(Map<String, Object?> json) {
    final favorite = json['id'] != null || json['favorite_id'] != null
        ? MobileFavorite.fromJson(json)
        : null;
    return MobileFavoriteState(
      productId: json['product_id'] as String? ?? favorite?.productId ?? '',
      isFavorite: json['is_favorite'] == true,
      favorite: favorite,
      product: json['product'] is Map
          ? CatalogProduct.fromJson(_stringMap(json['product']))
          : favorite?.product,
      raw: Map<String, Object?>.from(json),
    );
  }
}

class ProductReviewSummary {
  const ProductReviewSummary({required this.count, required this.average});

  final int count;
  final num average;

  static ProductReviewSummary fromJson(Map<String, Object?> json) {
    return ProductReviewSummary(
      count: _readInt(json['count']) ?? 0,
      average: _readNum(json['average']) ?? 0,
    );
  }
}

class ProductReview {
  const ProductReview({
    required this.id,
    required this.rating,
    required this.raw,
    this.notes,
    this.ratedBy,
    this.ratedAt,
    this.performerName,
  });

  final String id;
  final int rating;
  final String? notes;
  final String? ratedBy;
  final String? ratedAt;
  final String? performerName;
  final Map<String, Object?> raw;

  static ProductReview fromJson(Map<String, Object?> json) {
    return ProductReview(
      id: json['id'] as String? ?? '',
      rating: _readInt(json['rating']) ?? 0,
      notes: json['notes'] as String?,
      ratedBy: json['rated_by'] as String?,
      ratedAt: json['rated_at']?.toString(),
      performerName: json['performer_name'] as String?,
      raw: Map<String, Object?>.from(json),
    );
  }
}

class ProductReviewPage {
  const ProductReviewPage({
    required this.items,
    required this.summary,
    required this.hasMore,
    this.nextCursor,
  });

  final List<ProductReview> items;
  final ProductReviewSummary summary;
  final bool hasMore;
  final String? nextCursor;

  static ProductReviewPage fromJson(Map<String, Object?> json) {
    return ProductReviewPage(
      items: _listOfMaps(json['items']).map(ProductReview.fromJson).toList(),
      summary: ProductReviewSummary.fromJson(_stringMap(json['summary'])),
      hasMore: json['hasMore'] == true,
      nextCursor: json['nextCursor'] as String?,
    );
  }
}

class RecentSearch {
  const RecentSearch({
    required this.id,
    required this.query,
    required this.lastSearchedAt,
  });

  final String id;
  final String query;
  final String lastSearchedAt;

  static RecentSearch fromJson(Map<String, Object?> json) {
    return RecentSearch(
      id: json['id'] as String? ?? '',
      query: json['query'] as String? ?? '',
      lastSearchedAt: json['last_searched_at']?.toString() ?? '',
    );
  }
}

class CatalogCategory {
  const CatalogCategory({
    required this.id,
    required this.name,
    this.parent,
    this.image,
    this.description,
    this.enabled,
    this.isGroup,
    this.displayOrder,
  });

  final String id;
  final String name;
  final String? parent;
  final String? image;
  final String? description;
  final bool? enabled;
  final bool? isGroup;
  final int? displayOrder;

  static CatalogCategory fromJson(Map<String, Object?> json) {
    return CatalogCategory(
      id: (json['id'] ?? '') as String,
      name: json['name'] as String? ?? '',
      parent: json['parent'] as String?,
      image: json['image'] as String?,
      description: json['description'] as String?,
      enabled: json['enabled'] as bool?,
      isGroup: json['is_group'] as bool?,
      displayOrder: _readInt(json['display_order']),
    );
  }
}

class CatalogBrand {
  const CatalogBrand({required this.id, required this.name, this.image});

  final String id;
  final String name;
  final String? image;

  static CatalogBrand fromJson(Map<String, Object?> json) {
    return CatalogBrand(
      id: (json['id'] ?? '') as String,
      name: json['name'] as String? ?? '',
      image: json['image'] as String?,
    );
  }
}

class ProductSuggestion {
  const ProductSuggestion({required this.id, required this.label, this.image});

  final String id;
  final String label;
  final String? image;

  static ProductSuggestion fromJson(Map<String, Object?> json) {
    return ProductSuggestion(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      image: json['image'] as String?,
    );
  }
}

class MobileHome {
  const MobileHome({
    required this.version,
    required this.updatedAt,
    required this.cacheTtlSeconds,
    required this.locale,
    required this.filters,
    required this.blocks,
    required this.raw,
  });

  final int version;
  final String updatedAt;
  final int cacheTtlSeconds;
  final String locale;
  final List<HomeFilter> filters;
  final List<HomeBlock> blocks;
  final Map<String, Object?> raw;

  static MobileHome fromJson(Map<String, Object?> json) {
    return MobileHome(
      version: _readInt(json['version']) ?? 0,
      updatedAt: json['updated_at']?.toString() ?? '',
      cacheTtlSeconds: _readInt(json['cache_ttl_seconds']) ?? 0,
      locale: json['locale'] as String? ?? 'en',
      filters: _listOfMaps(json['filters']).map(HomeFilter.fromJson).toList(),
      blocks: _listOfMaps(json['blocks']).map(HomeBlock.fromJson).toList(),
      raw: Map<String, Object?>.from(json),
    );
  }
}

class HomeFilter {
  const HomeFilter({required this.key, required this.label});

  final String key;
  final String label;

  static HomeFilter fromJson(Map<String, Object?> json) {
    return HomeFilter(
      key: json['key'] as String? ?? '',
      label: json['label'] as String? ?? '',
    );
  }
}

class HomeBlock {
  const HomeBlock({
    required this.id,
    required this.type,
    required this.data,
    required this.raw,
  });

  final String id;
  final String type;
  final Map<String, Object?> data;
  final Map<String, Object?> raw;

  bool get isKnown =>
      bannerCarousel != null ||
      singleBanner != null ||
      productList != null ||
      categoryGrid != null ||
      brandStrip != null;

  HomeBannerCarouselData? get bannerCarousel =>
      type == 'banner_carousel' ? HomeBannerCarouselData.fromJson(data) : null;

  HomeSingleBannerData? get singleBanner =>
      type == 'single_banner' ? HomeSingleBannerData.fromJson(data) : null;

  HomeProductListData? get productList =>
      type == 'product_list' ? HomeProductListData.fromJson(data) : null;

  HomeCategoryGridData? get categoryGrid =>
      type == 'category_grid' ? HomeCategoryGridData.fromJson(data) : null;

  HomeBrandStripData? get brandStrip =>
      type == 'brand_strip' ? HomeBrandStripData.fromJson(data) : null;

  static HomeBlock fromJson(Map<String, Object?> json) {
    return HomeBlock(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? '',
      data: _stringMap(json['data']),
      raw: Map<String, Object?>.from(json),
    );
  }
}

class HomeBannerCarouselData {
  const HomeBannerCarouselData({required this.banners});

  final List<HomeBanner> banners;

  static HomeBannerCarouselData fromJson(Map<String, Object?> json) {
    return HomeBannerCarouselData(
      banners: _listOfMaps(json['banners']).map(HomeBanner.fromJson).toList(),
    );
  }
}

class HomeSingleBannerData {
  const HomeSingleBannerData({required this.banner});

  final HomeBanner banner;

  static HomeSingleBannerData fromJson(Map<String, Object?> json) {
    return HomeSingleBannerData(
      banner: HomeBanner.fromJson(_stringMap(json['banner'])),
    );
  }
}

class HomeBanner {
  const HomeBanner({
    required this.id,
    required this.image,
    required this.title,
    required this.subtitle,
    required this.buttonTitle,
    required this.gradient,
    required this.action,
    required this.raw,
  });

  final String id;
  final String image;
  final String title;
  final String subtitle;
  final String buttonTitle;
  final List<String> gradient;
  final HomeAction action;
  final Map<String, Object?> raw;

  static HomeBanner fromJson(Map<String, Object?> json) {
    return HomeBanner(
      id: json['id'] as String? ?? '',
      image: json['image'] as String? ?? '',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      buttonTitle: json['button_title'] as String? ?? '',
      gradient: (json['gradient'] as List? ?? const [])
          .map((value) => value.toString())
          .toList(),
      action: HomeAction.fromJson(_stringMap(json['action'])),
      raw: Map<String, Object?>.from(json),
    );
  }
}

class HomeAction {
  const HomeAction({required this.type, required this.value});

  final String type;
  final String value;

  static HomeAction fromJson(Map<String, Object?> json) {
    return HomeAction(
      type: json['type'] as String? ?? '',
      value: json['value']?.toString() ?? '',
    );
  }
}

class HomeProductListData {
  const HomeProductListData({
    required this.title,
    required this.seeAll,
    required this.respectsFilter,
    required this.products,
  });

  final String title;
  final bool seeAll;
  final bool respectsFilter;
  final List<HomeProductCard> products;

  static HomeProductListData fromJson(Map<String, Object?> json) {
    return HomeProductListData(
      title: json['title'] as String? ?? '',
      seeAll: json['see_all'] == true,
      respectsFilter: json['respects_filter'] == true,
      products: _listOfMaps(
        json['products'],
      ).map(HomeProductCard.fromJson).toList(),
    );
  }
}

class HomeProductCard {
  const HomeProductCard({
    required this.id,
    required this.name,
    required this.image,
    required this.price,
    required this.currency,
    required this.unit,
    required this.inStock,
    required this.rating,
    required this.ratingCount,
    required this.filter,
    required this.raw,
    this.originalPrice,
  });

  final String id;
  final String name;
  final String image;
  final num price;
  final num? originalPrice;
  final String currency;
  final String unit;
  final bool inStock;
  final num rating;
  final int ratingCount;
  final String filter;
  final Map<String, Object?> raw;

  static HomeProductCard fromJson(Map<String, Object?> json) {
    final effectivePrice = _readNum(json['effective_price']);
    return HomeProductCard(
      id: (json['id'] ?? json['product_id'] ?? '') as String,
      name: json['name'] as String? ?? '',
      image: json['image'] as String? ?? '',
      price: effectivePrice ?? _readNum(json['price']) ?? 0,
      originalPrice: _readNum(json['original_price']),
      currency: json['currency'] as String? ?? 'IQD',
      unit: json['unit'] as String? ?? '',
      inStock: json['in_stock'] == true,
      rating: _readNum(json['rating']) ?? 0,
      ratingCount: _readInt(json['rating_count']) ?? 0,
      filter: json['filter'] as String? ?? 'other',
      raw: Map<String, Object?>.from(json),
    );
  }
}

class HomeCategoryGridData {
  const HomeCategoryGridData({required this.title, required this.categories});

  final String title;
  final List<HomeCategoryCard> categories;

  static HomeCategoryGridData fromJson(Map<String, Object?> json) {
    return HomeCategoryGridData(
      title: json['title'] as String? ?? '',
      categories: _listOfMaps(
        json['categories'],
      ).map(HomeCategoryCard.fromJson).toList(),
    );
  }
}

class HomeCategoryCard {
  const HomeCategoryCard({
    required this.id,
    required this.title,
    required this.emoji,
    required this.backgroundColor,
  });

  final String id;
  final String title;
  final String emoji;
  final String backgroundColor;

  static HomeCategoryCard fromJson(Map<String, Object?> json) {
    return HomeCategoryCard(
      id: json['id'] as String? ?? '',
      title: (json['title'] ?? json['name'] ?? '').toString(),
      emoji: json['emoji'] as String? ?? '',
      backgroundColor: json['background_color'] as String? ?? '#FFFFFF',
    );
  }
}

class HomeBrandStripData {
  const HomeBrandStripData({required this.title, required this.brands});

  final String title;
  final List<HomeBrand> brands;

  static HomeBrandStripData fromJson(Map<String, Object?> json) {
    return HomeBrandStripData(
      title: json['title'] as String? ?? '',
      brands: _listOfMaps(json['brands']).map(HomeBrand.fromJson).toList(),
    );
  }
}

class HomeBrand {
  const HomeBrand({required this.id, required this.name, required this.image});

  final String id;
  final String name;
  final String image;

  static HomeBrand fromJson(Map<String, Object?> json) {
    return HomeBrand(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      image: json['image'] as String? ?? '',
    );
  }
}

class MobilePet {
  const MobilePet({
    required this.id,
    required this.name,
    required this.raw,
    this.species,
    this.type,
    this.breed,
    this.status,
    this.petStatus,
    this.isDisabled = false,
    this.birthDate,
    this.registrationDate,
    this.color,
    this.gender,
    this.weight,
    this.height,
    this.bloodType,
    this.play,
    this.activityExercise,
    this.foodBrand,
    this.foodType,
    this.description,
    this.note,
    this.image,
    this.isDeceased = false,
    this.deathDate,
  });

  final String id;
  final String name;
  final String? species;
  final String? type;
  final String? breed;
  final String? status;
  final String? petStatus;
  final bool isDisabled;
  final String? birthDate;
  final String? registrationDate;
  final String? color;
  final String? gender;
  final num? weight;
  final num? height;
  final String? bloodType;
  final String? play;
  final String? activityExercise;
  final String? foodBrand;
  final String? foodType;
  final String? description;
  final String? note;
  final String? image;
  final bool isDeceased;
  final String? deathDate;
  final Map<String, Object?> raw;

  static MobilePet fromJson(Map<String, Object?> json) {
    return MobilePet(
      id: (json['id'] ?? json['pet_id'] ?? '') as String,
      name: json['name'] as String? ?? '',
      species: json['species'] as String?,
      type: json['type'] as String?,
      breed: json['breed'] as String?,
      status: json['status'] as String?,
      petStatus: json['pet_status'] as String?,
      isDisabled: json['is_disabled'] == true,
      birthDate: json['birth_date'] as String?,
      registrationDate: json['registration_date'] as String?,
      color: json['color'] as String?,
      gender: json['gender'] as String?,
      weight: _readNum(json['weight']),
      height: _readNum(json['height']),
      bloodType: json['blood_type'] as String?,
      play: json['play'] as String?,
      activityExercise: json['activity_exercise'] as String?,
      foodBrand: json['food_brand'] as String?,
      foodType: json['food_type'] as String?,
      description: json['description'] as String?,
      note: json['note'] as String?,
      image: json['image'] as String?,
      isDeceased: json['is_deceased'] == true,
      deathDate: json['death_date'] as String?,
      raw: Map<String, Object?>.from(json),
    );
  }
}

class PetPhotoUploadResult {
  const PetPhotoUploadResult({
    required this.file,
    required this.pet,
    required this.raw,
  });

  final MobileFileAttachment file;
  final MobilePet pet;
  final Map<String, Object?> raw;

  static PetPhotoUploadResult fromJson(Map<String, Object?> json) {
    return PetPhotoUploadResult(
      file: MobileFileAttachment.fromJson(_stringMap(json['file'])),
      pet: MobilePet.fromJson(_stringMap(json['pet'])),
      raw: Map<String, Object?>.from(json),
    );
  }
}

class PetMedicalRecord {
  const PetMedicalRecord({
    required this.id,
    required this.type,
    required this.raw,
    this.pet,
    this.guardian,
    this.summary,
    this.administeredOn,
    this.nextDueDate,
    this.reminderEnabled = false,
    this.reminderStatus,
    this.notes,
  });

  final String id;
  final String type;
  final String? pet;
  final String? guardian;
  final String? summary;
  final String? administeredOn;
  final String? nextDueDate;
  final bool reminderEnabled;
  final String? reminderStatus;
  final String? notes;
  final Map<String, Object?> raw;

  static PetMedicalRecord fromJson(Map<String, Object?> json) {
    return PetMedicalRecord(
      id: (json['id'] ?? json['name'] ?? '') as String,
      type: json['type'] as String? ?? '',
      pet: json['pet'] as String?,
      guardian: json['guardian'] as String?,
      summary: json['summary'] as String?,
      administeredOn: json['administered_on']?.toString(),
      nextDueDate: json['next_due_date']?.toString(),
      reminderEnabled: json['reminder_enabled'] == true,
      reminderStatus: json['reminder_status'] as String?,
      notes: json['notes'] as String?,
      raw: Map<String, Object?>.from(json),
    );
  }
}

class PetMedicalEvent {
  const PetMedicalEvent({
    required this.type,
    required this.name,
    required this.raw,
    this.sourceDoctype,
    this.at,
    this.status,
    this.summary,
  });

  final String type;
  final String name;
  final String? sourceDoctype;
  final String? at;
  final String? status;
  final String? summary;
  final Map<String, Object?> raw;

  static PetMedicalEvent fromJson(Map<String, Object?> json) {
    return PetMedicalEvent(
      type: json['type'] as String? ?? '',
      name: json['name'] as String? ?? '',
      sourceDoctype: json['source_doctype'] as String?,
      at: json['at']?.toString(),
      status: json['status'] as String?,
      summary: json['summary'] as String?,
      raw: Map<String, Object?>.from(json),
    );
  }
}

class PetDocument {
  const PetDocument({
    required this.name,
    required this.raw,
    this.sourceDoctype,
    this.file,
    this.modified,
  });

  final String name;
  final String? sourceDoctype;
  final String? file;
  final String? modified;
  final Map<String, Object?> raw;

  static PetDocument fromJson(Map<String, Object?> json) {
    return PetDocument(
      name: json['name'] as String? ?? '',
      sourceDoctype: json['source_doctype'] as String?,
      file: json['file'] as String?,
      modified: json['modified']?.toString(),
      raw: Map<String, Object?>.from(json),
    );
  }
}

const Object _sentinel = Object();

int? _readInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

num? _readNum(Object? value) {
  if (value is num) return value;
  if (value is String) return num.tryParse(value);
  return null;
}

bool? _readBool(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized == '1' || normalized == 'true') return true;
    if (normalized == '0' || normalized == 'false') return false;
  }
  return null;
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
