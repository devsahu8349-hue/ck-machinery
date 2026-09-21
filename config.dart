// Values are injected at build time (see DEPLOY.md):
//   flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
// The anon key is designed to be public; security comes from the RLS policies.
// NEVER put the service_role key in this app.
class AppConfig {
  static const supabaseUrl = String.fromEnvironment('https://tvhlglisnhslmxtsttsi.supabase.co');
  static const supabaseAnonKey = String.fromEnvironment('sb_publishable_Z4zsAlHroSkRSbvV_27GdA_mRm-1AWP');
  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
