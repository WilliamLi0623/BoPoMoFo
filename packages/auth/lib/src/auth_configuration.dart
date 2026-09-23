class AuthConfiguration {
  const AuthConfiguration({
    required this.supabaseUrl,
    required this.publishableKey,
    required this.googleRedirectUri,
    this.appleRedirectUri,
  });

  final String supabaseUrl;
  final String publishableKey;
  final String googleRedirectUri;
  final String? appleRedirectUri;

  factory AuthConfiguration.fromEnvironment([Map<String, String>? environment]) {
    final values = environment;
    final url = _value(values, 'SUPABASE_URL');
    final key = _value(values, 'SUPABASE_PUBLISHABLE_KEY');
    final googleCallback = _value(values, 'GOOGLE_OAUTH_REDIRECT_URI');
    final appleCallback = _value(values, 'APPLE_REDIRECT_URI');

    final missing = <String>[
      if (url == null) 'SUPABASE_URL',
      if (key == null) 'SUPABASE_PUBLISHABLE_KEY',
      if (googleCallback == null) 'GOOGLE_OAUTH_REDIRECT_URI',
    ];
    if (missing.isNotEmpty) {
      throw AuthConfigurationError(missing);
    }

    return AuthConfiguration(
      supabaseUrl: url!,
      publishableKey: key!,
      googleRedirectUri: googleCallback!,
      appleRedirectUri: appleCallback,
    );
  }

  void validate() {
    final missing = <String>[
      if (supabaseUrl.trim().isEmpty) 'SUPABASE_URL',
      if (publishableKey.trim().isEmpty) 'SUPABASE_PUBLISHABLE_KEY',
      if (googleRedirectUri.trim().isEmpty) 'GOOGLE_OAUTH_REDIRECT_URI',
    ];
    final parsedUrl = Uri.tryParse(supabaseUrl.trim());
    if (parsedUrl == null ||
        !parsedUrl.hasAuthority ||
        parsedUrl.host.isEmpty ||
        !const {'http', 'https'}.contains(parsedUrl.scheme.toLowerCase())) {
      if (!missing.contains('SUPABASE_URL')) missing.add('SUPABASE_URL');
    }
    if (missing.isNotEmpty) throw AuthConfigurationError(missing);
  }

  static String? _value(Map<String, String>? environment, String name) {
    final resolved = environment == null
        ? switch (name) {
            'SUPABASE_URL' => const String.fromEnvironment(
                'SUPABASE_URL',
                defaultValue: '',
              ),
            'SUPABASE_PUBLISHABLE_KEY' => const String.fromEnvironment(
                'SUPABASE_PUBLISHABLE_KEY',
                defaultValue: '',
              ),
            'GOOGLE_OAUTH_REDIRECT_URI' => const String.fromEnvironment(
                'GOOGLE_OAUTH_REDIRECT_URI',
                defaultValue: '',
              ),
            'APPLE_REDIRECT_URI' => const String.fromEnvironment(
                'APPLE_REDIRECT_URI',
                defaultValue: '',
              ),
            _ => '',
          }
        : environment[name] ?? '';
    return resolved.trim().isEmpty ? null : resolved.trim();
  }
}

class AuthConfigurationError extends AuthFailure {
  AuthConfigurationError(this.missing)
      : super(
          kind: AuthFailureKind.configuration,
          message: 'Missing authentication configuration: ${missing.join(', ')}',
        );

  final List<String> missing;
}

enum AuthFailureKind {
  configuration,
  cancelled,
  provider,
  unsupportedPlatform,
}

class AuthFailure implements Exception {
  const AuthFailure({required this.kind, required this.message, this.cause});

  final AuthFailureKind kind;
  final String message;
  final Object? cause;

  @override
  String toString() => 'AuthFailure($kind): $message';
}
