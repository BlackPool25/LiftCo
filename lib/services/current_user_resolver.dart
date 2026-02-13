import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class CurrentUserResolver {
  static Future<Map<String, dynamic>?> resolveCurrentUserProfile(
    SupabaseClient client,
  ) async {
    try {
      final api = SupabaseService(client);
      final response = await api.getCurrentUser();
      final user = response['user'] as Map<String, dynamic>?;
      if (user != null) return user;
    } catch (_) {
      // Fallback to direct lookup below
    }

    final authUser = client.auth.currentUser;
    if (authUser == null) return null;

    return await client
        .from('users')
        .select()
        .eq('auth_id', authUser.id)
        .maybeSingle();
  }

  static Future<String?> resolveAppUserId(SupabaseClient client) async {
    final profile = await resolveCurrentUserProfile(client);
    if (profile != null && profile['id'] != null) {
      return profile['id'] as String;
    }

    return null;
  }
}