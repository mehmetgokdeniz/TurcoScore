# TurcoScore

[English](README.md) | **Türkçe**

Maç sonuçları, canlı skor, lig/puan tablosu ve oyuncu bilgilerini **anahtarsız,
açık** futbol veri API'lerinden alan Flutter skor uygulaması.

> İlk veri kaynağı her ağdan erişilemez durumdaydı (bot/WAF + captcha → 403),
> bu yüzden veri katmanı farklı bir açık kaynağa taşındı. Ekranlar hiçbir
> sağlayıcıya doğrudan ulaşmaz; tek bir arayüz üzerinden çağırır, kaynak
> değiştirmek tek satırlıktır.

## Özellikler

- **Maçlar** — tarih şeridi + canlı filtresi + favori çipi olan günlük liste
- **Maç detayı** — dakika dakika zaman çizelgesi (gol, penaltı, kart, oyuncu
  değişikliği, VAR), Türkçe istatistikler (topla oynama, şut, isabetli şut,
  fauller, korner, pas isabeti, xG), dizilis saha görünümü, son5 form rozetleri
  ve ikili maçlar
- **Ligler** — paralel çekilen **35** turnuva (8'li gruplar, ~3 sn): 13 kulüp
  ligi (Trendyol Süper Lig + Trendyol 1. Lig), 6 kupa, 16 milli takım turnuvası
  (Dünya Kupası + elemeleri, UEFA Uluslar Ligi, Avrupa Şampiyonası + eleme,
  Copa América, Afrika/Asya/Altın Kupa, CONCACAF Uluslar Ligi, dostluklar)
- **Puan tablosu** — sezon seçimli tablo; eleme turnuvalarında her grup ayrı
  bölüm
- **Arama** — takım, lig ve oyuncu tek kutuda, 350 ms debounce;
  "galatasaray" → Galatasaray, "messi" → oyuncu profili
- **Oyuncu profili** — yaş, boy, kilo, mevki, doğum tarihi/yeri, kontrat,
  sezon istatistikleri; şeffaf formüllü **tahmini puan**
  (`core/utils/player_rating.dart`): `<6 kırmızı`, `<7 turuncu`, `<8.5 yeşil`,
  `≥8.5 mavi`
- **Kadro ekranı** — dizilise göre saha görünümü (fotoğraf, forma no, tam ad),
  puan rozeti ve yedekler
- **Favoriler ve bildirimler** (yerel, sunucu gerekmez): maç başladı, gol,
  kırmızı kart. Uygulama açıkken **60 sn**'de bir (`AppShell` zamanlayıcısı),
  arka planda **15 dk**'da bir (`workmanager`, `lib/background.dart`) kontrol
  edilir; yalnızca **yeni** olaylar bildirilir. Android13+ izni ilk açılışta
  istenir.
- **Demo modu** — ağ hatası / 403 / 429 / 451'de repository `DemoData`'ya
  döner ve UI'da "demo veri" şeridi görünür

## Çalıştırma

```bash
flutter pub get
flutter run
```

Doğrulama:

```bash
flutter analyze
flutter test
```

Release APK: `flutter build apk --release` → `build/app/outputs/flutter-apk/app-release.apk`

Derlenmiş release APK ayrıca [`releases/`](releases/) klasöründe mevcuttur.

## Yapılandırma (.env)

Gizlenecek **API anahtarı yok** — uygulamanın kullandığı tüm uçlar anahtarsız
ve açıktır. Taban adresler ve (şu an kullanılmayan) anahtar alanları
[`.env.example`](.env.example) içinde durur:

```bash
cp .env.example .env   # .env git'e girmez
```

| Dosya | Git'te mi? | Amaç |
|---|---|---|
| `.env.example` | evet | şablon: taban adresler, gelecekteki anahtar alanları |
| `.env` | **hayır** | yerel kopyanız, asla commit edilmez |

Lisanslı bir kaynağa geçerseniz anahtarı `.env`'e yazın; `.gitignore` zaten
`.env`, `.env.*` dosyalarını hariç tutup yalnızca `.env.example`'ı dahil eder.

## Mimari

```
lib/
├── main.dart                     # Provider + MaterialApp (tr locale, açık/koyu tema)
├── background.dart               # 15 dakikalık arka plan favori kontrolü
├── core/
│   ├── constants/api_constants.dart   # yedek kaynak uçları
│   ├── network/api_client.dart        # HTTP + timeout + yedekli taban adres + hata sınıflandırma
│   ├── notifications/match_notifier.dart
│   ├── theme/app_theme.dart           # Material 3 tema
│   ├── utils/                         # json_utils, errors, player_rating
│   └── widgets/                       # TeamLogo, StatusBadge, Error/Empty/Loading, DemoBanner
├── data/
│   ├── models/                        # MatchEvent, Tournament, StandingRow, PlayerProfile...
│   ├── sources/                       # veri sözleşmesi + aktif/pasif sağlayıcılar
│   ├── repositories/score_repository.dart  # kaynak + demo yedeği tek kapısı
│   ├── favorites/favorite_store.dart
│   └── demo/demo_data.dart            # erişilemezlikte örnek veri
├── state/                             # ChangeNotifier controller'lar
│   ├── matches_controller.dart
│   ├── leagues_controller.dart        # TournamentsController + StandingsController
│   ├── detail_controllers.dart        # MatchDetailController + PlayerController
│   ├── search_controller.dart         # 350ms debounce'lu arama
│   └── load_state.dart
└── features/
    ├── shell/app_shell.dart           # alt menü: Maçlar / Ligler / Arama
    ├── matches/                       # liste (tarih şeridi + canlı filtresi), maç detayı
    ├── leagues/                       # lig listesi, puan tablosu (sezon seçimi)
    ├── search/                        # takım / lig / oyuncu arama
    ├── player/                        # oyuncu profili
    └── team/                          # takım kadrosu
```

Katman kuralı: `features → state → data → core`. Ekranlar repository'ye doğrudan
ulaşmaz, controller üzerinden çağırır. Kaynak değiştirmek ekranları etkilemez:
`ScoreRepository(source: ...)`.

## Veri katmanı

- **Tek sözleşme** — `data/sources/score_data_source.dart` uygulamanın bağlı
  olduğu tek arayüzdür; somut sağlayıcılar bunu uygular ve repository birini
  seçer.
- **Aktif / pasif** — aktif sağlayıcı repository'de bağlıdır; ikinci bir
  sağlayıcı ağaçta yedek olarak durur ve tek satırla geri açılır.
- **Yedek zinciri** — bir sağlayıcı birden fazla taban adres tanımlayabilir;
  ağ hatası / 403 / 429 / 451'de istemci sıradakine geçer.
- **Demo yedeği** — tüm kaynaklar düşerse repository paketlenmiş `DemoData`'yı
  sunar, UI hata yerine "demo veri" şeridi gösterir.
- **Birleşik arama** — takım/lig ve oyuncu sonuçları farklı sağlayıcılardan
  çekilip tek listede birleştirilir, oyuncular en başta.

## Bilinen sınırlar

- **Gerçek maç puanı:** ücretsiz kaynaklar genelde puan yayımlamaz ya da
  erişime kapalıdır; bu yüzden puan gol/asist/kart/kurtarış ve maç sonucundan
  `core/utils/player_rating.dart` içindeki şeffaf formülle türetilir ve
  *tahmini* olarak etiketlenir. Resmi puan için lisanslı API anahtarı gerekir.
- **Global oyuncu araması:** çoğu ücretsiz arama ucu yalnız takım ve lig
  döndürür. Oyunculara maç kadrosu ve takım listesinden erişilir.
- **TFF alt ligleri:** mevcut kaynak yalnız üst iki ligi kapsar; 3. Lig ve
  Türkiye Kupası'nda veri yok, o satırlar boş kalır. Tam kapsam için
  API-Football / football-data.org gibi anahtarlı kaynak gerekir.

## Model ayrıştırma kuralı

API tipleri tutarsız döndürür (skor alanı hem `int` hem `string` olabilir).
Modellerde `tryInt / tryString / tryMap` kullanılır; bilinmeyen alanlar sessizce
`null` geçer. Yeni alan eklerken doğrudan `json['x']` okumayın.

## Uygulama ikonu

- Kaynak görsel `tool/make_icon.dart` ile işlenir (damalı arka plan kenarlardan
  tespit edilip lacivert zemine doldurulur, 1024x PNG'ye çevrilir):
  `dart run tool/make_icon.dart`
- Launcher ikonları: `dart run flutter_launcher_icons`
  (Android mipmap + iOS AppIcon, `pubspec.yaml` > `flutter_launcher_icons`).

## Sonraki adımlar (öneri)

- Favori takımlar/oyuncular (`shared_preferences` + yerel bildirimler)
- Canlı skor için 30-60 sn'lik polling
- Gol krallığı / liderlik tabloları
- `cached_network_image` için disk limiti ayarı

## Hukuki / limit

Burada kullanılan açık futbol veri API'leri genelde resmi değildir. İstek
sayısını düşük tutun, polling eklerken 30-60 sn aralık kullanın. Ticari yayında
lisanslı kaynak tercih edin.

## Lisans

[LICENSE](LICENSE) dosyasına bakın.
