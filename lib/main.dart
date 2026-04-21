import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:window_manager/window_manager.dart';

import 'blocs/auth/auth_bloc.dart';
import 'blocs/auth/auth_event.dart';
import 'blocs/project/project_bloc.dart';
import 'blocs/secret/secret_bloc.dart';
import 'blocs/settings/settings_bloc.dart';
import 'blocs/settings/settings_event.dart';
import 'blocs/settings/settings_state.dart';
import 'blocs/audit/audit_bloc.dart';
import 'blocs/search/search_bloc.dart';
import 'blocs/import/import_bloc.dart';

import 'screens/lock_screen.dart';
import 'theme/app_theme.dart';

import 'services/encryption_service.dart';
import 'services/storage_service.dart';
import 'services/export_service.dart';
import 'services/import_service.dart';
import 'services/clipboard_service.dart';
import 'services/biometric_service.dart';

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
  final biometricService = BiometricService();

  runApp(MyApp(
    storageService: storageService,
    encryptionService: encryptionService,
    exportService: exportService,
    clipboardService: clipboardService,
    biometricService: biometricService,
  ));
}

class MyApp extends StatelessWidget {
  final StorageService storageService;
  final EncryptionService encryptionService;
  final ExportService exportService;
  final ClipboardService clipboardService;
  final BiometricService biometricService;

  const MyApp({
    super.key,
    required this.storageService,
    required this.encryptionService,
    required this.exportService,
    required this.clipboardService,
    required this.biometricService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: storageService),
        RepositoryProvider.value(value: encryptionService),
        RepositoryProvider.value(value: exportService),
        RepositoryProvider.value(value: clipboardService),
        RepositoryProvider.value(value: biometricService),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>(
            create: (context) =>
                AuthBloc(storageService, encryptionService, biometricService)..add(CheckLockStatus()),
          ),
          BlocProvider<ProjectBloc>(
            create: (context) => ProjectBloc(storageService),
          ),
          BlocProvider<AuditBloc>(
            create: (context) => AuditBloc(),
          ),
          BlocProvider<SearchBloc>(
            create: (context) => SearchBloc(storageService),
          ),
          BlocProvider<SecretBloc>(
            create: (context) {
              final auditBloc = context.read<AuditBloc>();
              return SecretBloc(storageService, encryptionService, auditBloc, clipboardService);
            },
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

            return Listener(
              onPointerDown: (_) => context.read<AuthBloc>().userActivityDetected(),
              onPointerMove: (_) => context.read<AuthBloc>().userActivityDetected(),
              child: MaterialApp(
                title: 'Secret Vault',
                debugShowCheckedModeBanner: false,
                themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
                theme: AppTheme.light,
                darkTheme: AppTheme.dark,
                home: const LockScreen(),
              ),
            );
          },
        ),
      ),
    );
  }
}
