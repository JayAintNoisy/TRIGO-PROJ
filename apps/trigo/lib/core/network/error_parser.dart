String extractApiError(dynamic data, [String fallback = 'Something went wrong']) {
  if (data is Map<String, dynamic>) {
    final error = data['error'];
    if (error is Map<String, dynamic>) {
      return error['message'] as String? ??
          error['code'] as String? ??
          fallback;
    } else if (error is String) {
      return error;
    }
  }
  return fallback;
}
