import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:geges_smartbarber/utils/image_helper.dart';

class AppImage extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final String? base64;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final BorderRadius? borderRadius;
  final Color? color;
  final BlendMode? colorBlendMode;

  const AppImage({
    super.key,
    this.imageUrl,
    this.width,
    this.height,
    this.base64,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.borderRadius,
    this.color,
    this.colorBlendMode,
  });

  @override
  Widget build(BuildContext context) {
    final String? path = imageUrl ?? base64;

    if (path == null || path.isEmpty) {
      return _buildErrorWidget();
    }

    Widget image;

    if (path.startsWith('http') || path.startsWith('https')) {
      image = CachedNetworkImage(
        imageUrl: path,
        width: width,
        height: height,
        fit: fit,
        color: color,
        colorBlendMode: colorBlendMode,
        placeholder: (context, url) => placeholder ?? _buildPlaceholder(),
        errorWidget: (context, url, error) => errorWidget ?? _buildErrorWidget(),
      );
    } else {
      try {
        final bytes = ImageHelper.decodeBase64(path);
        if (bytes.isEmpty) {
          return _buildErrorWidget();
        }
        image = Image.memory(
          bytes,
          width: width,
          height: height,
          fit: fit,
          color: color,
          colorBlendMode: colorBlendMode,
          errorBuilder: (context, error, stackTrace) => errorWidget ?? _buildErrorWidget(),
        );
      } catch (e) {
        return _buildErrorWidget();
      }
    }

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: image,
      );
    }

    return image;
  }

  Widget _buildPlaceholder() {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[900],
      child: const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[900],
      child: const Center(
        child: Icon(Icons.broken_image, color: Colors.white24),
      ),
    );
  }
}
