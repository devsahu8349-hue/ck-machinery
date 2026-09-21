class AppConfig {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://tvhlglisnhslmxtsttsi.supabase.co',
  );
  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InR2aGxnbGlzbmhzbG14dHN0dHNpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTAwMDc5NTYsImV4cCI6MjEwNTU4Mzk1Nn0.Dwda0EujVC8JxmeRTpGoCfjb_P4wmRPjK38sqQteYiE',
  );
  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
