import 'package:design_system/design_system.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import 'bootstrap.dart';
import 'features/dashboard/dashboard_page.dart';
import 'features/lesson/lesson_page.dart';
import 'features/onboarding/onboarding_page.dart';
import 'features/review/review_page.dart';
import 'features/settings/settings_page.dart';
import 'features/keyboard/keyboard_page.dart';
import 'features/account/account_page.dart';
import 'routes.dart';
import 'l10n/app_localizations.dart';
import 'localization/app_locale_controller.dart';

class BopomofoApp extends StatefulWidget {
  const BopomofoApp(
      {required this.dependencies,
      required this.localeController,
      this.onExportReady,
      this.reviewSessionFactory,
      super.key});

  final AppDependencies dependencies;
  final AppLocaleController localeController;
  final ValueChanged<String>? onExportReady;
  final ReviewSessionFactory? reviewSessionFactory;

  @override
  State<BopomofoApp> createState() => _BopomofoAppState();
}

class _BopomofoAppState extends State<BopomofoApp> {
  int _navIndex = 0;
  String _page = 'onboarding';
  String _path = 'pinyin';

  @override
  void initState() {
    super.initState();
    widget.localeController.addListener(_onLocaleChanged);
  }

  @override
  void didUpdateWidget(BopomofoApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.localeController != widget.localeController) {
      oldWidget.localeController.removeListener(_onLocaleChanged);
      widget.localeController.addListener(_onLocaleChanged);
    }
  }

  @override
  void dispose() {
    widget.localeController.removeListener(_onLocaleChanged);
    super.dispose();
  }

  void _onLocaleChanged() => setState(() {});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Bopomofo',
        debugShowCheckedModeBanner: false,
        locale: widget.localeController.locale,
        localizationsDelegates: [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: const [
          Locale('en'),
          Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
          Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
        ],
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
        routes: {
          AppRoutes.dashboard: (_) => DashboardPage(
              learningEngine: widget.dependencies.learningEngine,
              repository: widget.dependencies.repository),
          AppRoutes.lesson: (context) => LessonPage(
              learningEngine: widget.dependencies.learningEngine,
              repository: widget.dependencies.repository,
              path: _path,
              onReview: () =>
                  Navigator.of(context).pushNamed(AppRoutes.review)),
          AppRoutes.review: (context) => Scaffold(
                appBar: AppBar(
                    title: Text(AppLocalizations.of(context)!.shellTitle)),
                body: SafeArea(
                  child: ReviewPage(
                      sessionFactory: widget.reviewSessionFactory ??
                          widget.dependencies.createReviewSessionRuntime),
                ),
              ),
          AppRoutes.settings: (_) => SettingsPage(
              localeController: widget.localeController,
              authService: widget.dependencies.authService,
              syncService: widget.dependencies.syncService,
              repository: widget.dependencies.repository,
              onReturnedToGuest: _returnToGuest,
              onExportReady: widget.onExportReady ?? _copyExport),
          AppRoutes.keyboard: (_) => KeyboardPage(
              learningEngine: widget.dependencies.learningEngine,
              repository: widget.dependencies.repository),
          AppRoutes.account: (_) => AccountPage(
              authService: widget.dependencies.authService,
              repository: widget.dependencies.repository,
              onReturnedToGuest: _returnToGuest),
        },
        onGenerateRoute: (settings) {
          if (settings.name != AppRoutes.onboarding) return null;
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (context) => OnboardingPage(
              learningEngine: widget.dependencies.learningEngine,
              authService: widget.dependencies.authService,
              syncService: widget.dependencies.syncService,
              repository: widget.dependencies.repository,
              onPathSelected: (path) => _selectNamedPath(context, path),
            ),
          );
        },
        home: Builder(
          builder: (context) {
            final labels = AppLocalizations.of(context)!;
            return AppScaffold(
              title: labels.shellTitle,
              homeLabel: labels.home,
              dashboardLabel: labels.dashboard,
              settingsLabel: labels.settings,
              selectedIndex: _navIndex,
              onDestinationSelected: _navigate,
              body: _body(),
            );
          },
        ),
      );

  Widget _body() => switch (_page) {
        'dashboard' => DashboardPage(
            learningEngine: widget.dependencies.learningEngine,
            repository: widget.dependencies.repository),
        'lesson' => LessonPage(
            learningEngine: widget.dependencies.learningEngine,
            repository: widget.dependencies.repository,
            path: _path,
            onReview: () => setState(() => _page = 'review')),
        'review' => ReviewPage(
            sessionFactory: widget.reviewSessionFactory ??
                widget.dependencies.createReviewSessionRuntime,
            onReturnToLearning: () => setState(() => _page = 'lesson')),
        'settings' => SettingsPage(
            localeController: widget.localeController,
            authService: widget.dependencies.authService,
            syncService: widget.dependencies.syncService,
            repository: widget.dependencies.repository,
            onReturnedToGuest: _returnToGuest,
            onExportReady: widget.onExportReady ?? _copyExport),
        _ => OnboardingPage(
            learningEngine: widget.dependencies.learningEngine,
            authService: widget.dependencies.authService,
            syncService: widget.dependencies.syncService,
            repository: widget.dependencies.repository,
            onPathSelected: (path) => setState(() {
                  _path = path;
                  _page = 'lesson';
                })),
      };

  void _navigate(int index) => setState(() {
        _navIndex = index;
        _page = switch (index) {
          1 => 'dashboard',
          2 => 'settings',
          _ => 'onboarding',
        };
      });

  void _returnToGuest() => setState(() {
        _page = 'onboarding';
        _navIndex = 0;
      });

  void _selectNamedPath(BuildContext context, String path) {
    setState(() {
      _path = path;
      _page = 'lesson';
    });
    Navigator.of(context).pushReplacementNamed(AppRoutes.lesson);
  }

  void _copyExport(String value) {
    Clipboard.setData(ClipboardData(text: value));
  }
}
