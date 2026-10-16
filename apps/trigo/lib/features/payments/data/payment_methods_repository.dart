import 'package:dio/dio.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/error_parser.dart';

/// A driver-owned payment method and whether it is currently switched on.
///
/// Cash is always enabled and never carries a QR code; the e-wallets are off
/// until the driver uploads one.
class DriverPaymentMethod {
  final String method;
  final bool isEnabled;
  final String? qrCodeUrl;

  const DriverPaymentMethod({
    required this.method,
    required this.isEnabled,
    this.qrCodeUrl,
  });

  factory DriverPaymentMethod.fromJson(Map<String, dynamic> json) {
    return DriverPaymentMethod(
      method: json['method']?.toString() ?? '',
      isEnabled: json['isEnabled'] == true,
      qrCodeUrl: json['qrCodeUrl'] as String?,
    );
  }

  DriverPaymentMethod copyWith({bool? isEnabled, String? qrCodeUrl}) {
    return DriverPaymentMethod(
      method: method,
      isEnabled: isEnabled ?? this.isEnabled,
      qrCodeUrl: qrCodeUrl ?? this.qrCodeUrl,
    );
  }
}

/// One enabled method attached to a driver or ride payload, as seen by a
/// passenger (cash included, cash first).
class EnabledPaymentMethod {
  final String method;
  final String? qrCodeUrl;

  const EnabledPaymentMethod({required this.method, this.qrCodeUrl});

  factory EnabledPaymentMethod.fromJson(Map<String, dynamic> json) {
    return EnabledPaymentMethod(
      method: json['method']?.toString() ?? '',
      qrCodeUrl: json['qrCodeUrl'] as String?,
    );
  }

  /// Parses the `paymentMethods` / `driverPaymentMethods` payload field.
  ///
  /// Falls back to cash alone when the field is missing or malformed so a
  /// passenger always has at least one payable option.
  static List<EnabledPaymentMethod> listFrom(dynamic value) {
    if (value is! List) return const [EnabledPaymentMethod(method: 'cash')];

    final parsed = <EnabledPaymentMethod>[];
    for (final item in value) {
      if (item is Map) {
        final method = EnabledPaymentMethod.fromJson(
          Map<String, dynamic>.from(item),
        );
        if (method.method.isNotEmpty) parsed.add(method);
      }
    }
    return parsed.isEmpty
        ? const [EnabledPaymentMethod(method: 'cash')]
        : parsed;
  }
}

/// Turns a stored `/uploads/...` path into an absolute URL for image loading.
///
/// The API base URL already carries its mount prefix (for example
/// `http://host:4000/api`), so the path must be appended to that prefix rather
/// than resolved from the host root — resolving `/uploads/x` from the root
/// would request `http://host:4000/uploads/x` and 404.
String absoluteUploadUrl(String path) {
  if (path.startsWith('http://') || path.startsWith('https://')) return path;

  final base = Uri.parse(ApiEndpoints.baseUrl);
  final basePath = base.path.endsWith('/')
      ? base.path.substring(0, base.path.length - 1)
      : base.path;
  final suffix = path.startsWith('/') ? path : '/$path';

  return base.replace(path: '$basePath$suffix').toString();
}

class PaymentMethodsRepository {
  final Dio _dio = dioClient;

  /// The driver's own methods, including the always-on cash default.
  Future<List<DriverPaymentMethod>> getDriverPaymentMethods() async {
    try {
      final response = await _dio.get(ApiEndpoints.driverPaymentMethods);
      final list = (response.data['data'] as List?) ?? [];
      return list
          .whereType<Map>()
          .map((item) => DriverPaymentMethod.fromJson(
                Map<String, dynamic>.from(item),
              ))
          .toList();
    } on DioException catch (e) {
      throw Exception(extractApiError(e.response?.data));
    }
  }

  /// Enables or disables one method. Enabling requires a [qrCodeUrl].
  Future<DriverPaymentMethod> setDriverPaymentMethod(
    String method, {
    required bool isEnabled,
    String? qrCodeUrl,
  }) async {
    try {
      final response = await _dio.put(
        ApiEndpoints.driverPaymentMethod(method),
        data: {
          'isEnabled': isEnabled,
          if (qrCodeUrl != null) 'qrCodeUrl': qrCodeUrl,
        },
      );
      return DriverPaymentMethod.fromJson(
        Map<String, dynamic>.from(response.data['data'] as Map),
      );
    } on DioException catch (e) {
      throw Exception(extractApiError(e.response?.data));
    }
  }

  /// Records the method the passenger will pay with; returns the updated ride.
  Future<dynamic> setRidePaymentMethod(String rideId, String method) async {
    try {
      final response = await _dio.patch(
        ApiEndpoints.ridePaymentMethod(rideId),
        data: {'method': method},
      );
      return response.data['data'];
    } on DioException catch (e) {
      throw Exception(extractApiError(e.response?.data));
    }
  }
}
