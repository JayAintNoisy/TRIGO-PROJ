import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiEndpoints {
  static String get baseUrl =>
      dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:4000/api';

  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String me = '/auth/me';
  static const String refresh = '/auth/refresh';

  static const String rides = '/rides';
  static const String applyDriver = '/drivers/apply';
  static const String driverMe = '/drivers/me';
  static const String driverOnlineStatus = '/drivers/online-status';
  static const String trackingLocation = '/tracking/location';
  static const String municipalities = '/municipalities';
}
