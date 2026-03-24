/// Shared API configuration for the MT request application.
class MtRequestApi {
  MtRequestApi._();

  static const String baseUrl = 'http://26.99.205.41:9000/drugs';
  static const Duration requestTimeout = Duration(seconds: 10);
  static const Duration reportTimeout = Duration(seconds: 15);
  static const Duration uploadTimeout = Duration(seconds: 20);

  static Uri uri(String path, {Map<String, dynamic>? queryParameters}) {
    final normalizedQuery = queryParameters == null
        ? null
        : queryParameters.map(
            (key, value) => MapEntry(key, value?.toString() ?? ''),
          );

    return Uri.parse('$baseUrl$path').replace(queryParameters: normalizedQuery);
  }
}
