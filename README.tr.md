# TurcoScore

[English](README.md) | **Türkçe**

Maç sonuçları, canlı skor, lig/puan tablosu ve oyuncu bilgilerini **ESPN**
açık API'sinden alan Flutter skor uygulaması.

> SofaScore ilk tercihti; bot/WAF + captcha tüm ağlardan 403 döndüğü için
> kaynak ESPN'e çevrildi. SofaScore kodu `data/sources/sofascore_source.dart`
> içinde korunur.

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
  bölüm (`Group A` → `A Grubu`)
- **Arama** — takım + lig (ESPN) ve oyuncu (Maçkolik) tek kutuda, 350 ms
  debounce; "galatasaray" → Galatasaray, "messi" → oyuncu profili
- **Oyuncu profili** — yaş, boy, kilo, mevki, doğum tarihi/yeri, kontrat,
  sezon istatistikleri; şeffaf formüllü **tahmini puan**
  (`core/utils/player_rating.dart`): `<6 kırmızı`, `<7 turuncu`, `<8.5 yeşil`,
  `≥8.5 mavi`
- **Kadro ekranı** — dizilise göre saha görünümü (fotoğraf, forma no, tam ad),
  SofaScore tarzı puan rozeti ve yedekler
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
dart run tool/probe_espn.dart   # canlı API uçtan uca kontrolü
```

Release APK: `flutter build apk --release` → `build/app/outputs/flutter-apk/app-release.apk`

Derlenmiş release APK ayrıca [`releases/`](releases/) klasöründe mevcuttur.

## Yapılandırma (.env)

Gizlenecek **API anahtarı yok** — uygulamanın kullandığı tüm uçlar anahtarsız,
açık API'lerdir. Taban adresler ve (şu an kullanılmayan) anahtar alanları
[`.env.example`](.env.example) içinde durur:

```bash
cp .env.example .env   # .env git'e girmez
```

| Dosya | Git'te mi? | Amaç |
|---|---|---|
| `.env.example` | evet | şablon: taban adresler, gelecekteki anahtar alanları |
| `.env` | **hayır** | yerel kopyanız, asla commit edilmez |

Lisanslı bir kaynağa geçerseniz (API-Football, football-data.org, ...) anahtarı
`.env`'e yazın; `.gitignore` zaten `.env`, `.env.*` dosyalarını hariç tutup
yalnızca `.env.example`'ı dahil eder.

## Mimari

```
lib/
├── main.dart                     # Provider + MaterialApp (tr locale, açık/koyu tema)
├── background.dart               # 15 dakikalık arka plan favori kontrolü
├── core/
│   ├── constants/api_constants.dart   # SofaScore uç noktaları (yedek kaynak)
│   ├── network/api_client.dart        # HTTP + timeout + yedekli taban adres + hata sınıflandırma
│   ├── notifications/match_notifier.dart
│   ├── theme/app_theme.dart           # Material 3 tema
│   ├── utils/                         # json_utils, errors, player_rating
│   └── widgets/                       # TeamLogo, StatusBadge, Error/Empty/Loading, DemoBanner
├── data/
│   ├── models/                        # MatchEvent, Tournament, StandingRow, PlayerProfile, EventBundle...
│   ├── sources/
│   │   ├── score_data_source.dart     # Uygulamanın tek veri sözleşmesi (arayüz)
│   │   ├── espn_source.dart           # AKTİF kaynak (+ lig konfigürasyonu)
│   │   ├── sofascore_source.dart      # pasif, kod korunur
│   │   └── mackolik_client.dart       # Türk ligleri / oyuncu profilleri
│   ├── repositories/score_repository.dart  # Kaynak + demo yedeği tek kapısı
│   ├── favorites/favorite_store.dart
│   └── demo/demo_data.dart            # Erişilemezlikte örnek veri
├── state/                             # ChangeNotifier controller'lar
│   ├── matches_controller.dart
│   ├── leagues_controller.dart        # TournamentsController + StandingsController
│   ├── detail_controllers.dart        # MatchDetailController + PlayerController
│   ├── search_controller.dart         # 350ms debounce'lu arama
│   └── load_state.dart
└── features/
    ├── shell/app_shell.dart           # Alt menü: Maçlar / Ligler / Arama
    ├── matches/                       # Liste (tarih şeridi + canlı filtresi), maç detayı
    ├── leagues/                       # Lig listesi, puan tablosu (sezon seçimi)
    ├── search/                        # Takım / lig / oyuncu arama
    ├── player/                        # Oyuncu profili
    └── team/                          # Takım kadrosu
```

Katman kuralı: `features → state → data → core`. Ekranlar repository'ye doğrudan
ulaşmaz, controller üzerinden çağırır. Kaynak değiştirmek ekranları etkilemez:
`ScoreRepository(source: SofaScoreSource())`.

## ESPN API (aktif)

Anahtar gerekmez; tüm uç noktalar 2026-10'da canlı doğrulandı
(`dart run tool/probe_espn.dart` ile tekrarlanır).

| Amaç | Uç nokta |
|---|---|
| Günlük maçlar (lig başına) | `/apis/site/v2/sports/soccer/{slug}/scoreboard?dates=yyyyMMdd` |
| Canlı maçlar | Aynı ucun bugünkü çağrısı → `status.type.state == 'in'` filtresi |
| Maç detayı | `/apis/site/v2/sports/soccer/{slug}/summary?event={id}` |
| İstatistik | özet içinde `boxscore.teams[].statistics` |
| Maç olayları | özet içinde `header.competitions[0].details` |
| Kadrolar | özet içinde `rosters[]` (dizilis + ilk 11 sıralı) |
| **Puan tablosu** | `/apis/v2/sports/soccer/{slug}/standings?season={yıl}` |
| Sezon seçimi | `seasons` → {yıl}-{yıl+1} ve bir önceki |
| Lig listesi | Sabit konfigürasyon (`EspnSource.leagues`) |
| Takım kadrosu | `/apis/site/v2/sports/soccer/{slug}/teams/{id}/roster` |
| Oyuncu profili | `sports.core.api.espn.com/v2/sports/soccer/athletes/{id}` |
| Arama | `/apis/common/v3/search?q=&sport=soccer` (takım + lig) |

Önemli notlar:

- **Standings yolu farklı:** `site/v2` yolu boş `{}` döndürür; doğru yol
  `/apis/v2/...`'dir (docs: "site/v2 returns a stub").
- **Sezon çözümü:** istenen yıl boşsa ESPN'in sezonsuz (son dolu) çağrısına
  düşülür; sezon listesi yanıtın `seasons` alanından gelir. Eleme turnuvalarında
  her grup ayrı bölüm olarak gösterilir (`Group A` → `A Grubu`).
- **Arama:** `sport=soccer` yoksa futbol takımları hiç dönmez. ESPN aramasında
  oyuncu sonucu yok; oyunculara maç kadrosu ve takım listesinden erişilir.
- **İstatistik/olay biçimi** skorboard ile özet arasında farklı gelir
  (`athletesInvolved` vs `participants[].athlete`) — ikisi de okunur.
- **Maç özeti:** `keyEvents` üzerinden dakika dakika zaman çizelgesi — gol,
  penaltı golü/kaçtı, sarı/kırmızı kart, oyuncu değişikliği (gelen/giden isim),
  VAR ve diğer olaylar; hepsi Türkçe etiketle, skorlar işlenerek.
- **Son5 maç:** her iki takımın G/B/M formu özet sekmesinde renkli rozetlerle.
- **İki takım arasındaki maçlar:** `seasonseries` (head-to-head) listelenir;
  satıra dokununca o maçın detayı açılır.
- **İstatistikler Türkçedir** (Topla oynama, Şut, İsabetli şut, Fauller,
  Korner, Pas isabeti, xG...).
- **Arama kelimeye göre çalışır:** ESPN'in arama ucu metin araması yapmadığı
  (popülerlik listesi döndürdüğü) için takım dizini **yerel olarak** izlenen
  35 ligden kurulur (ilk aramada ~3 sn, sonrası anlık). "galatasaray" →
  Galatasaray, "süper lig" → Trendyol Süper Lig + takımları.
- **Tarih düzeltmesi:** maç özeti nesnesinde `header.date` yoktur; tarih
  `competitions[0].date` okunur — eskiden detay ekranı bugünün tarihini
  gösteriyordu.
- **Görseller:** takım logoları ESPN'in tekli `logo` alanından, yoksa
  `a.espncdn.com/i/teamlogos/soccer/500/{id}.png` CDN'inden gelir. Lig logoları
  çekirdek lig ucundan alınır ve önbellekte tutulur; ayrıca scoreboard yanıtıyla
  da önbelleğe yazılır, maç listesi başlıklarında da görünür.
- **İsimlendirme:** Türkçe ligler sponsorlu adla gösterilir
  (ör. `Trendyol Süper Lig`).
- **Kadro ekranı:** dizilise göre saha görünümü (fotoğraf, forma no, **tam ad**),
  SofaScore tarzı renkli puan rozeti ve yedekler listesi. Takım kadrolarında da
  oyuncu fotoğrafları görünür.
- **Oyuncu puanı:** ESPN puan yayımlamaz; puan gol/asist/kart/kurtarış ve maç
  sonucundan `core/utils/player_rating.dart` içindeki şeffaf formülle türetilir
  ve "tahmini" olarak etiketlenir.
- **Demo modu:** Ağ hatası / 403 / 429 / 451 alındığında repository otomatik
  `DemoData`'ya döner ve UI'da "demo veri" şeridi gösterilir.
- **Hukuki/limit:** ESPN'in resmi olmayan API'si; istek sayısını düşük tutun,
  polling eklerken 30-60 sn aralık kullanın. Ticari yayında lisanslı kaynak
  tercih edin.

## Maçkolik kaynakları (Türk ligleri + futbolcular)

`lib/data/sources/mackolik_client.dart` — resmi olmayan uçlar (UTF-8):

| Amaç | Uç nokta |
|---|---|
| Oyuncu araması | `/AjaxHandlers/SearchHandler.aspx?q=` (JS dizi literal) |
| Oyuncu profili | `/Player/Default.aspx?id={id}` (bio + Maç/Gol/Asist/Şut) |
| Puan tablosu | `/AjaxHandlers/StandingHandler.ashx?op=standing&id={seasonId}` (JSON) |

- **Arama birleşiktir:** oyuncular Maçkolik'ten, takımlar/ligler ESPN'den
  gelir; oyuncu sonuçları en başta gösterilir. Örnek: `messi` →
  "Lionel Messi (Inter Miami)" → profil: yaş, boy, kilo, mevki, doğum tarihi/yeri,
  kontrat, **sezon: 25 maç / 23 gol / 11 asist**.
- **Puan tablosu sütun eşlemesi** (`Standing2.js` render'ından doğrulandı):
  `[2]+[3] O`, `[4]+[5] G`, `[6]+[7] B`, `[8]+[9] M`, `[10]+[11] A`,
  `[12]+[13] Y`, `[14]+[15]+[17] P`.
- **Trendyol 1. Lig:** ESPN'de veri yokken Maçkolik JSON'u devreye girer
  (`espnTournamentToSeason`: 1→73482, 2→73487).

### Bilinen sınırlar (ücretsiz kaynak araştırması sonucu)

- **Gerçek maç puanı:** SofaScore 403/captcha, FotMob imzalı/kapalı, ESPN
  puan yayımlamaz, Maçkolik'in API'si yok (yalnız HTML). Bu yüzden puan
  istatistikten türetilir. Gerçek puan için lisanslı API anahtarı gerekir.
- **Global oyuncu araması:** ESPN araması oyuncu sonucunu yok sayar
  (`type=player` sorguyu yok sayar), TheSportsDB ücretsiz planında oyuncu
  profilini 404 döndürür. Oyunculara maç kadrosu ve takım listesinden erişilir.
- **TFF alt ligleri:** ESPN'de yalnız `tur.1` (Süper Lig) ve `tur.2`
  (1. Lig) var; 3. Lig ve Türkiye Kupası için slug yok. TheSportsDB ücretsiz
  planında puan tablosu 5 satırla, günlük maç 3 olayla sınırlı. Tam kapsam için
  API-Football/football-data gibi anahtarlı kaynak gerekir.
  `tur.2` ESPN'de şu an boş (sezon verisi yok) — liste görünür, tablo boş.

## SofaScore (pasif kaynak)

Erişilemezlik kanıtı: bu makineden `www.sofascore.com` ve `api.sofascore.com`
tamamen 403 (robots.txt dahil), farklı bir ağdaki istek `captcha.html`'e
yönlendiriliyor; `api.sofascore.app` boş 200 dönüyor. Captcha/engel aşma
girişimi bilinçli olarak yapılmadı.

Kod korunuyor: uç noktalar `core/constants/api_constants.dart`, istemci
`data/sources/sofascore_source.dart` içinde. Kaynak geri dönmek için yeterli:
`ScoreRepository(source: SofaScoreSource())`.

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
- Gol krallığı / liderlik tabloları (`common/v3/.../statistics/byathlete`)
- `cached_network_image` için disk limiti ayarı

## Lisans

[LICENSE](LICENSE) dosyasına bakın.
