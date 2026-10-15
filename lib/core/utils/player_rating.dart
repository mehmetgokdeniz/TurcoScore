/// ESPN oyuncu puanlaması yayımlamadığı için puan, oyuncunun maç istatistiklerinden
/// şeffaf bir formülle türetilir. **Tahminidir**, resmi puan değildir.
///
/// Saf Dart'tır (Flutter bağımlılığı yok) ki kaynak katmanı ve testler
/// platformsuz çalışsın. Renk eşlemesi `core/widgets/rating_badge.dart` içinde.
double estimatePlayerRating({
  required Map<String, double> stats,
  required String? positionCode,
  required String? winnerCode,
  required bool isHome,
}) {
  double stat(String key) => stats[key] ?? 0;

  // 'CM-L', 'RM', 'CD-L' gibi kodlardan ilk harf pozisyon ailesini verir.
  final family = (positionCode ?? '').isEmpty ? '' : positionCode![0];
  final isGoalkeeper = family == 'G';

  var rating = 6.3;

  if (!isGoalkeeper) {
    rating += stat('totalGoals') * 1.0;
    rating += stat('goalAssists') * 0.6;
  } else {
    rating += (stat('saves') * 0.08).clamp(0.0, 0.6);
    rating -= stat('goalsConceded') * 0.2;
    if (stat('goalsConceded') == 0 && stat('appearances') > 0) rating += 0.7;
  }

  rating -= stat('yellowCards') * 0.3;
  rating -= stat('redCards') * 1.4;
  rating -= stat('ownGoals') * 0.8;

  if (winnerCode != null) {
    final won = winnerCode != 'draw' && (winnerCode == 'home') == isHome;
    final drew = winnerCode == 'draw';
    rating += won ? 0.4 : (drew ? 0.15 : -0.3);
  }

  return rating.clamp(3.0, 10.0).toDouble();
}

/// SofaScore benzeri renk kademeleri: kırmızı < 6 <= turuncu < 7 <= yeşil < 8.5 <= mavi.
enum RatingTier { red, orange, green, blue }

RatingTier ratingTier(double rating) {
  if (rating < 6) return RatingTier.red;
  if (rating < 7) return RatingTier.orange;
  if (rating < 8.5) return RatingTier.green;
  return RatingTier.blue;
}

String ratingLabel(double rating) => rating.toStringAsFixed(1);
