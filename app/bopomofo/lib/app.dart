import 'dart:async';

import 'package:design_system/design_system.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import 'bootstrap.dart';
import 'features/dashboard/dashboard_page.dart';
import 'features/lesson/lesson_page.dart';
import 'features/lesson/learning_path.dart';
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
  LearningPath _path = LearningPath.pinyin;

  StreamSubscription<Object?>? _authSubscription;

  @override
  void initState() {
    super.initState();
    widget.localeController.addListener(_onLocaleChanged);
    _listenToAuth();
  }

  @override
  void didUpdateWidget(BopomofoApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.localeController != widget.localeController) {
      oldWidget.localeController.removeListener(_onLocaleChanged);
      widget.localeController.addListener(_onLocaleChanged);
    }
    if (oldWidget.dependencies.authService !=
        widget.dependencies.authService) {
      _listenToAuth();
    }
  }

  @override
  void dispose() {
    widget.localeController.removeListener(_onLocaleChanged);
    _authSubscription?.cancel();
    super.dispose();
  }

  void _onLocaleChanged() => setState(() {});

  // The OAuth callback completes after signInWithGoogle() returns, so pages
  // that show the account state rebuild when the session arrives.
  void _listenToAuth() {
    _authSubscription?.cancel();
    _authSubscription = widget.dependencies.authService.authStateChanges
        .listen((_) {
      if (mounted) setState(() {});
    }, onError: (Object _) {});
  }

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
          AppRoutes.lesson: (context) => _coursePage(
                context,
                onReview: () => Navigator.of(context).pushNamed(AppRoutes.review),
              ),
          AppRoutes.review: (context) => Scaffold(
                appBar: AppBar(
                    title: Text(AppLocalizations.of(context)!.shellTitle)),
                body: SafeArea(
                  child: ReviewPage(sessionFactory: _sessionFactory()),
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
              body: _body(context),
            );
          },
        ),
      );

  Widget _body(BuildContext context) => switch (_page) {
        'dashboard' => DashboardPage(
            learningEngine: widget.dependencies.learningEngine,
            repository: widget.dependencies.repository),
        'lesson' => _coursePage(
            context, onReview: () => setState(() => _page = 'review')),
        'review' => ReviewPage(
            sessionFactory: _sessionFactory(),
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

  ReviewSessionFactory _sessionFactory([LearningLesson? lesson]) =>
      widget.reviewSessionFactory ??
      () => widget.dependencies.createReviewSessionRuntime(
            path: lesson?.path,
            lessonNumber: lesson?.number ?? 1,
          );

  LessonPage _coursePage(BuildContext context, {required VoidCallback onReview}) {
    final path = _path;
    return LessonPage(
      key: ValueKey(path),
      path: path,
      loadCompleted: () => widget.dependencies.repository.local.completedQuizScopes(
        lessonsForPath(path).map((lesson) => lesson.scope),
      ),
      onPractice: (lesson) => Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (context) => Scaffold(
            appBar: AppBar(title: Text(AppLocalizations.of(context)!.courseLesson(lesson.number))),
            body: SafeArea(
              child: ReviewPage(
                sessionFactory: _sessionFactory(lesson),
                onNextLesson: lesson.hasNext ? () => Navigator.of(context).pop(true) : null,
              ),
            ),
          ),
        ),
      ),
      onReview: onReview,
    );
  }

  void _selectNamedPath(BuildContext context, LearningPath path) {
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
