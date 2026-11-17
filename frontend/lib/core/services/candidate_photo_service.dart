import 'package:flutter/foundation.dart';

import 'supabase_service.dart';

class CandidatePhotoService {
  static const _extensions = ['jpg', 'png', 'webp'];

  static String imageExtension(Uint8List bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff) {
      return 'jpg';
    }
    if (bytes.length >= 4 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4e &&
        bytes[3] == 0x47) {
      return 'png';
    }
    if (bytes.length >= 12 &&
        String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
        String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
      return 'webp';
    }
    throw StateError('Choose a valid JPG, PNG, or WebP photo.');
  }

  Future<String> upload({required String uid, required Uint8List bytes}) async {
    if (SupabaseService.client.auth.currentUser?.id != uid) {
      throw StateError('Sign in before updating your profile photo.');
    }
    final ext = imageExtension(bytes);
    final publicUrl = await SupabaseService.uploadProfilePhoto(
      userId: uid,
      bytes: bytes,
      fileExtension: ext,
    );
    final updated = await SupabaseService.client
        .from('candidate_profiles')
        .update({
          'profile_photo_url': publicUrl,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('user_id', uid)
        .select('id')
        .maybeSingle();
    if (updated == null) throw StateError('Could not save your profile photo.');

    // Keep only the new format after its URL has been saved.
    try {
      await SupabaseService.client.storage.from('profile-photos').remove([
        for (final oldExt in _extensions)
          if (oldExt != ext) '$uid/avatar.$oldExt',
        '$uid/avatar.jpeg',
      ]);
    } catch (error) {
      debugPrint('[Photo cleanup] $error');
    }
    return publicUrl;
  }

  Future<void> delete(String uid) async {
    if (SupabaseService.client.auth.currentUser?.id != uid) {
      throw StateError('Sign in before removing your profile photo.');
    }
    await SupabaseService.client.storage.from('profile-photos').remove([
      for (final ext in [..._extensions, 'jpeg']) '$uid/avatar.$ext',
    ]);
    final updated = await SupabaseService.client
        .from('candidate_profiles')
        .update({
          'profile_photo_url': null,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('user_id', uid)
        .select('id')
        .maybeSingle();
    if (updated == null) {
      throw StateError('Could not clear your profile photo.');
    }
  }
}
