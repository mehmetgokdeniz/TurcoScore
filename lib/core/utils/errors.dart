import '../network/api_client.dart';

/// Kullanıcıya gösterilecek kısa hata metni.
String humanError(Object error) {
  if (error is ApiException) {
    if (error.statusCode == null) return 'Bağlantı kurulamadı';
    if (error.statusCode == 403) return 'Veri kaynağı erişimi reddedildi (403)';
    if (error.statusCode == 429) return 'Çok fazla istek, biraz bekleyin (429)';
    return 'Sunucu hatası (${error.statusCode})';
  }
  return 'Beklenmeyen bir hata oluştu';
}
