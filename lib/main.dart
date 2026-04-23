import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'blocs/auth/auth_bloc.dart';
import 'blocs/auth/auth_event.dart';
import 'blocs/project/project_bloc.dart';
import 'blocs/secret/secret_bloc.dart';
import 'blocs/settings/settings_bloc.dart';
import 'blocs/settings/settings_event.dart';
import 'blocs/settings/settings_state.dart';
import 'blocs/search/search_bloc.dart';
import 'blocs/import/import_bloc.dart';

import 'screens/lock_screen.dart';
import 'theme/app_theme.dart';

import 'services/encryption_service.dart';
import 'services/storage_service.dart';
import 'services/export_service.dart';
import 'services/import_service.dart';
import 'services/clipboard_service.dart';
import 'services/tag_service.dart';
import 'services/extension_service.dart';
import 'widgets/extension_approval_dialog.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();
    const windowOptions = WindowOptions(
      size: Size(1280, 780),
      minimumSize: Size(1024, 640),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
      title: 'Secret Vault',
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  final storageService = StorageService();
  await storageService.init();

  final encryptionService = EncryptionService();
  final exportService = ExportService(storageService, encryptionService);
  final clipboardService = ClipboardService();
  final tagService = TagService();
  final extensionService = ExtensionService(storageService, encryptionService);
  await extensionService.start();

  runApp(MyApp(
    storageService: storageService,
    encryptionService: encryptionService,
    exportService: exportService,
    clipboardService: clipboardService,
    tagService: tagService,
    extensionService: extensionService,
  ));
}

class MyApp extends StatelessWidget {
  final StorageService storageService;
  final EncryptionService encryptionService;
  final ExportService exportService;
  final ClipboardService clipboardService;
  final TagService tagService;
  final ExtensionService extensionService;
  
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  const MyApp({
    super.key,
    required this.storageService,
    required this.encryptionService,
    required this.exportService,
    required this.clipboardService,
    required this.tagService,
    required this.extensionService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: extensionService),
      ],
      child: MultiRepositoryProvider(
        providers: [
          RepositoryProvider.value(value: storageService),
          RepositoryProvider.value(value: encryptionService),
          RepositoryProvider.value(value: exportService),
          RepositoryProvider.value(value: clipboardService),
          RepositoryProvider.value(value: tagService),
        ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>(
            create: (context) =>
                AuthBloc(storageService, encryptionService)..add(CheckLockStatus()),
          ),
          BlocProvider<ProjectBloc>(
            create: (context) => ProjectBloc(storageService),
          ),
          BlocProvider<SearchBloc>(
            create: (context) => SearchBloc(storageService),
          ),
          BlocProvider<SecretBloc>(
            create: (context) => SecretBloc(storageService, encryptionService, clipboardService),
          ),
          BlocProvider<ImportBloc>(
            create: (context) => ImportBloc(ImportService(storageService, encryptionService)),
          ),
          BlocProvider<SettingsBloc>(
            create: (context) {
              final authBloc = context.read<AuthBloc>();
              final secretBloc = context.read<SecretBloc>();
              return SettingsBloc(
                storageService,
                exportService,
                authBloc,
                secretBloc,
                clipboardService,
              )..add(LoadSettings());
            },
          ),
        ],
        child: BlocBuilder<SettingsBloc, SettingsState>(
          builder: (context, state) {
            bool isDarkMode = true;
            if (state is SettingsLoaded) {
              isDarkMode = state.isDarkMode;
            }

            return _ExtensionRequestListener(
              extensionService: extensionService,
              child: Listener(
                onPointerDown: (_) => context.read<AuthBloc>().userActivityDetected(),
                onPointerMove: (_) => context.read<AuthBloc>().userActivityDetected(),
                child: MaterialApp(
                  navigatorKey: MyApp.navigatorKey,
                  title: 'Secret Vault',
                  debugShowCheckedModeBanner: false,
                  themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
                  theme: AppTheme.light,
                  darkTheme: AppTheme.dark,
                  home: const LockScreen(),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
}
}

class _ExtensionRequestListener extends StatefulWidget {
  final ExtensionService extensionService;
  final Widget child;

  const _ExtensionRequestListener({
    required this.extensionService,
    required this.child,
  });

  @override
  State<_ExtensionRequestListener> createState() => _ExtensionRequestListenerState();
}

class _ExtensionRequestListenerState extends State<_ExtensionRequestListener> {
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = widget.extensionService.requests.listen(_handleRequest);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _handleRequest(ExtensionRequest request) async {
    final context = MyApp.navigatorKey.currentContext;
    if (context == null) {
      request.completer.complete(false);
      return;
    }

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ExtensionApprovalDialog(
        origin: request.origin,
        secretTitle: request.secretTitle,
      ),
    );

    request.completer.complete(result ?? false);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
