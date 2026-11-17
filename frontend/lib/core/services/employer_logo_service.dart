import 'package:flutter/foundation.dart';

import 'candidate_photo_service.dart';
import 'supabase_service.dart';

class EmployerLogoService {
  static const _extensions = ['jpg', 'png', 'webp', 'jpeg'];

  Future<String> upload({required String uid, required Uint8List bytes}) async {
    if (SupabaseService.client.auth.currentUser?.id != uid) {
      throw StateError('Sign in before updating your company logo.');
    }
    final extension = CandidatePhotoService.imageExtension(bytes);
    final url = await SupabaseService.uploadProfilePhoto(
      userId: uid,
      bytes: bytes,
      fileExtension: extension,
    );
    final updated = await SupabaseService.client
        .from('employers')
        .update({
          'logo_url': url,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('user_id', uid)
        .select('id')
        .maybeSingle();
    if (updated == null) throw StateError('Could not save your company logo.');

    try {
      await SupabaseService.client.storage.from('profile-photos').remove([
        for (final oldExtension in _extensions)
          if (oldExtension != extension) '$uid/avatar.$oldExtension',
      ]);
    } catch (error) {
      debugPrint('[Company logo cleanup] $error');
    }
    return url;
  }

  Future<void> delete(String uid) async {
    if (SupabaseService.client.auth.currentUser?.id != uid) {
      throw StateError('Sign in before removing your company logo.');
    }
    await SupabaseService.client.storage.from('profile-photos').remove([
      for (final extension in _extensions) '$uid/avatar.$extension',
    ]);
    final updated = await SupabaseService.client
        .from('employers')
        .update({
          'logo_url': null,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('user_id', uid)
        .select('id')
        .maybeSingle();
    if (updated == null) {
      throw StateError('Could not remove your company logo.');
    }
  }
}
