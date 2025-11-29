import 'dart:convert';
import 'package:flutter/material.dart';

class GenUiImage extends StatelessWidget {
  final Map<String, dynamic> component;

  const GenUiImage({super.key, required this.component});

  @override
  Widget build(BuildContext context) {
    final imageDef = component['Image'];
    if (imageDef == null) {
      return const SizedBox.shrink();
    }

    final src = imageDef['src']?['literalString'] as String?;
    final semanticLabel =
        imageDef['semanticLabel']?['literalString'] as String?;

    if (src == null) {
      return const SizedBox.shrink();
    }

    if (src.startsWith('data:image')) {
      // Handle base64 image
      try {
        final base64String = src.split(',').last;
        final imageBytes = base64Decode(base64String);
        return Image.memory(
          imageBytes,
          semanticLabel: semanticLabel,
          fit: BoxFit.contain,
        );
      } catch (e) {
        return Text('Error decoding image: $e');
      }
    } else {
      // Handle network image
      return Image.network(
        src,
        semanticLabel: semanticLabel,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Text('Error loading image: $error');
        },
      );
    }
  }
}
