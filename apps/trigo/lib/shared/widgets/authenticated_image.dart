import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';

/// Renders an uploaded image that lives behind the authenticated
/// `/uploads/...` route.
///
/// The route requires a bearer token, so [Image.network] is used with the
/// stored access token attached. A missing token or a failed request degrades
/// to [placeholder] instead of throwing.
class AuthenticatedImage extends StatelessWidget {
  const AuthenticatedImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
  });

  /// Absolute URL of the image.
  final String url;

  final BoxFit fit;

  /// Shown while the token/request is in flight.
  final Widget? placeholder;

  /// Shown when the image cannot be loaded.
  final Widget? errorWidget;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: tokenProvider.getToken(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return placeholder ?? const _ImagePlaceholder();
        }

        final token = snapshot.data;
        if (token == null || token.isEmpty) {
          return errorWidget ?? const _ImagePlaceholder();
        }

        return Image.network(
          url,
          fit: fit,
          headers: {'Authorization': 'Bearer $token'},
          loadingBuilder: (context, child, progress) =>
              progress == null ? child : (placeholder ?? const _ImagePlaceholder()),
          errorBuilder: (context, error, stackTrace) =>
              errorWidget ?? const _ImagePlaceholder(),
        );
      },
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF1F5F9),
      child: Center(
        child: Icon(
          Icons.qr_code_2,
          size: 22,
          color: Colors.grey.shade400,
        ),
      ),
    );
  }
}
