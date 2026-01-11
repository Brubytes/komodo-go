import 'dart:io';
import 'dart:math';

import 'package:image/image.dart' as img;

void main(List<String> args) {
  final inputPath = args.isNotEmpty ? args.first : 'assets/komodo-go-logo.png';
  final outputPath = args.length > 1
      ? args[1]
      : 'assets/komodo-go-logo_rounded.png';

  final inputFile = File(inputPath);
  if (!inputFile.existsSync()) {
    stderr.writeln('Input file not found: $inputPath');
    exit(2);
  }

  final decoded = img.decodePng(inputFile.readAsBytesSync());
  if (decoded == null) {
    stderr.writeln('Failed to decode PNG: $inputPath');
    exit(3);
  }

  final image = decoded.convert(numChannels: 4);
  final width = image.width;
  final height = image.height;

  final radius = min(width, height) * 0.12;
  final radiusSq = radius * radius;

  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      var outside = false;

      if (x < radius && y < radius) {
        final dx = (radius - 1) - x;
        final dy = (radius - 1) - y;
        outside = (dx * dx + dy * dy) > radiusSq;
      } else if (x >= width - radius && y < radius) {
        final dx = x - (width - radius);
        final dy = (radius - 1) - y;
        outside = (dx * dx + dy * dy) > radiusSq;
      } else if (x < radius && y >= height - radius) {
        final dx = (radius - 1) - x;
        final dy = y - (height - radius);
        outside = (dx * dx + dy * dy) > radiusSq;
      } else if (x >= width - radius && y >= height - radius) {
        final dx = x - (width - radius);
        final dy = y - (height - radius);
        outside = (dx * dx + dy * dy) > radiusSq;
      }

      if (outside) {
        image.getPixel(x, y).a = 0;
      }
    }
  }

  File(outputPath)
    ..createSync(recursive: true)
    ..writeAsBytesSync(img.encodePng(image));
  stdout.writeln('Wrote: $outputPath');
}
