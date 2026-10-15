import 'package:flutter/material.dart';

import '../utils/player_rating.dart';

/// Puan kademesine göre SofaScore tarzı renk.
Color ratingColor(double rating) {
  switch (ratingTier(rating)) {
    case RatingTier.red:
      return const Color(0xFFE03131);
    case RatingTier.orange:
      return const Color(0xFFF08C00);
    case RatingTier.green:
      return const Color(0xFF2FA84F);
    case RatingTier.blue:
      return const Color(0xFF3B7DDD);
  }
}

/// Renkli oyuncu puan rozeti (ör. `7.4`).
class RatingBadge extends StatelessWidget {
  const RatingBadge({super.key, required this.rating, this.fontSize = 12});

  final double rating;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: fontSize * 0.5, vertical: 2),
      decoration: BoxDecoration(
        color: ratingColor(rating),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        ratingLabel(rating),
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
