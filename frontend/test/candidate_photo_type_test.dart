import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vetrijobs/core/services/candidate_photo_service.dart';

void main() {
  test('profile photo type comes from image bytes', () {
    expect(
      CandidatePhotoService.imageExtension(
        Uint8List.fromList([0xff, 0xd8, 0xff, 0x00]),
      ),
      'jpg',
    );
    expect(
      CandidatePhotoService.imageExtension(
        Uint8List.fromList([0x89, 0x50, 0x4e, 0x47]),
      ),
      'png',
    );
    expect(
      CandidatePhotoService.imageExtension(
        Uint8List.fromList('RIFF1234WEBP'.codeUnits),
      ),
      'webp',
    );
    expect(
      () => CandidatePhotoService.imageExtension(
        Uint8List.fromList('not an image'.codeUnits),
      ),
      throwsStateError,
    );
  });
}
