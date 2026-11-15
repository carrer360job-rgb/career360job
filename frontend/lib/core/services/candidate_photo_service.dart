import 'dart:typed_data';
import 'supabase_service.dart';

class CandidatePhotoService {
  Future<String> upload({
    required String uid,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final ext = fileName.contains('.') ? fileName.split('.').last : 'jpg';
    try {
      final publicUrl = await SupabaseService.uploadProfilePhoto(
        userId: uid,
        bytes: bytes,
        fileExtension: ext,
      );
      return publicUrl;
    } catch (e) {
      // Return Supabase direct public URL fallback
      final path = '$uid/avatar.$ext';
      return SupabaseService.client.storage
          .from('profile-photos')
          .getPublicUrl(path);
    }
  }

  Future<void> delete(String uid) async {
    try {
      await SupabaseService.client.storage
          .from('profile-photos')
          .remove(['$uid/avatar.jpg', '$uid/avatar.png']);
    } catch (_) {}
  }
}
