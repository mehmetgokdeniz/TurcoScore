import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Yuvarlak görsel (oyuncu fotoğrafı, takım/lig logosu) + baş harf yedeği.
class NetworkCircleAvatar extends StatelessWidget {
  const NetworkCircleAvatar({
    super.key,
    required this.url,
    required this.name,
    required this.radius,
    this.backgroundColor,
    this.textColor,
    this.initialsBackground,
  });

  final String? url;
  final String name;
  final double radius;
  final Color? backgroundColor;
  final Color? textColor;
  final Color? initialsBackground;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    final list = parts.toList();
    if (list.length == 1) return list.first.substring(0, 1).toUpperCase();
    return (list.first.substring(0, 1) + list.last.substring(0, 1)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fallback = Container(
      width: radius * 2,
      height: radius * 2,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor ?? scheme.surfaceContainerHighest,
      ),
      child: Text(
        _initials,
        style: TextStyle(
          fontSize: radius * 0.8,
          fontWeight: FontWeight.w700,
          color: textColor ?? scheme.onSurfaceVariant,
        ),
      ),
    );

    if (url == null || url!.isEmpty) return fallback;

    return ClipOval(
      child: SizedBox(
        width: radius * 2,
        height: radius * 2,
        child: CachedNetworkImage(
          imageUrl: url!,
          fit: BoxFit.cover,
          placeholder: (_, _) => fallback,
          errorWidget: (_, _, _) => fallback,
        ),
      ),
    );
  }
}
