// Uygulama ikonunu hazırlar:
//  1) Yapıştırılan görseldeki damalı (checkerboard) arka plan + gölge,
//     kenarlardan başlatılan dolu alan (flood fill) ile dışarı sayılır,
//  2) Dışarısı ikonun lacivert zeminiyle doldurulur (beyaz top dokunulmaz),
//  3) Kareye çekilir,1024x1024 PNG olarak kaydedilir.
//
// Çalıştırma: dart run tool/make_icon.dart
// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

const String sourcePath =
    r'C:\Users\mehme\AppData\Local\Temp\commandcode-images\image-1-1792022927781.jpg';
const String outputPath = 'assets/icon/app_icon.png';

/// Nötr (gri) piksel mi? Damalı arka plan ve gölge nötrtür.
bool _isNeutral(int r, int g, int b) {
  final maxChannel = math.max(r, math.max(g, b));
  final minChannel = math.min(r, math.min(g, b));
  return (maxChannel - minChannel) <= 14;
}

Future<void> main() async {
  final sourceFile = File(sourcePath);
  if (!sourceFile.existsSync()) {
    print('Kaynak bulunamadı: $sourcePath');
    return;
  }

  final decoded = img.decodeImage(sourceFile.readAsBytesSync());
  if (decoded == null) {
    print('Görsel çözümlenemedi');
    return;
  }
  final image = decoded;
  print('kaynak: ${image.width}x${image.height}');

  final width = image.width;
  final height = image.height;

  // 1) Dış kenarlardan başlayarak nötr pikselleri dışarı işaretle (flood fill).
  final exterior = Uint8List(width * height);
  final stack = <int>[];

  void pushIfTraversable(int x, int y) {
    if (x < 0 || y < 0 || x >= width || y >= height) return;
    final index = y * width + x;
    if (exterior[index] == 1) return;
    final pixel = image.getPixel(x, y);
    if (_isNeutral(pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt())) {
      exterior[index] = 1;
      stack.add(index);
    }
  }

  for (var x = 0; x < width; x++) {
    pushIfTraversable(x, 0);
    pushIfTraversable(x, height - 1);
  }
  for (var y = 0; y < height; y++) {
    pushIfTraversable(0, y);
    pushIfTraversable(width - 1, y);
  }

  while (stack.isNotEmpty) {
    final index = stack.removeLast();
    final x = index % width;
    final y = index ~/ width;
    pushIfTraversable(x + 1, y);
    pushIfTraversable(x - 1, y);
    pushIfTraversable(x, y + 1);
    pushIfTraversable(x, y - 1);
  }

  // 2) İkon sınırlarını (dışarı boyamadan) bul.
  var minX = width, minY = height, maxX = 0, maxY = 0;
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      if (exterior[y * width + x] == 1) continue;
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }
  }
  print('ikon sınırı: x=$minX..$maxX y=$minY..$maxY');

  // 3) İkonun İÇİNDEN lacivert zemini örnekleyip dışarısını boya
  //    (üst-orta bölge daima ikonun lacivert arka planıdır).
  final boxTop = minY;
  final boxBottom = maxY;
  final sampleY = (boxTop + (boxBottom - boxTop) * 0.06).round().clamp(0, height - 1);
  final sampleX = ((minX + maxX) ~/ 2).clamp(0, width - 1);
  final bgPixel = image.getPixel(sampleX, sampleY);
  final bgR = bgPixel.r.toInt();
  final bgG = bgPixel.g.toInt();
  final bgB = bgPixel.b.toInt();
  print('zemin rengi: rgb($bgR,$bgG,$bgB) @($sampleX,$sampleY)');

  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      if (exterior[y * width + x] == 1) {
        image.setPixelRgb(x, y, bgR, bgG, bgB);
      }
    }
  }

  // 4) Sınırları hafif içeri kırp ve kareye çek.
  final inset = (math.max(maxX - minX, maxY - minY) * 0.01).round();
  minX += inset;
  minY += inset;
  maxX -= inset;
  maxY -= inset;

  final boxSize = math.max(maxX - minX + 1, maxY - minY + 1);
  final centerX = ((minX + maxX) ~/ 2);
  final centerY = ((minY + maxY) ~/ 2);
  var cropX = centerX - boxSize ~/ 2;
  var cropY = centerY - boxSize ~/ 2;
  cropX = cropX.clamp(0, width - 1);
  cropY = cropY.clamp(0, height - 1);
  final cropW = math.min(boxSize, width - cropX);
  final cropH = math.min(boxSize, height - cropY);

  final cropped = img.copyCrop(image, x: cropX, y: cropY, width: cropW, height: cropH);
  final resized = img.copyResize(cropped, width: 1024, height: 1024);

  Directory('assets/icon').createSync(recursive: true);
  File(outputPath).writeAsBytesSync(img.encodePng(resized));
  print('yazıldı: $outputPath (${File(outputPath).lengthSync()} bayt)');
}
