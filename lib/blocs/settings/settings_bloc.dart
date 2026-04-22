import 'package:flutter_bloc/flutter_bloc.dart';
import '../../services/clipboard_service.dart';
import '../../services/storage_service.dart';
import '../../services/export_service.dart';
import '../auth/auth_bloc.dart';
import '../secret/secret_event.dart';
import '../secret/secret_bloc.dart';
import 'settings_event.dart';
import 'settings_state.dart';

class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  final StorageService _storageService;
  final ExportService _exportService;
  final AuthBloc _authBloc;
  final SecretBloc _secretBloc;
  final ClipboardService _clipboardService;

  SettingsBloc(
    this._storageService, 
    this._exportService, 
    this._authBloc, 
    this._secretBloc,
    this._clipboardService,
  ) : super(SettingsInitial()) {
    on<LoadSettings>(_onLoadSettings);
    on<ToggleTheme>(_onToggleTheme);
    on<SetAutoLockDuration>(_onSetAutoLockDuration);
    on<SetClipboardClearDuration>(_onSetClipboardClearDuration);
    on<ExportProjectEvent>(_onExportProject);
    on<ImportEnvFile>(_onImportEnvFile);
  }

  void _onLoadSettings(LoadSettings event, Emitter<SettingsState> emit) {
    try {
      final isDarkMode = _storageService.settingsBox.get('isDarkMode', defaultValue: true);
      final autoLockMinutes = _storageService.settingsBox.get('autoLockMinutes', defaultValue: 15);
      final clipboardSeconds = _storageService.settingsBox.get('clipboardClearSeconds', defaultValue: 30);
      
      _authBloc.setAutoLockMinutes(autoLockMinutes);
      _clipboardService.updateDuration(Duration(seconds: clipboardSeconds));
      
      emit(SettingsLoaded(
        isDarkMode: isDarkMode,
        autoLockMinutes: autoLockMinutes,
        clipboardClearSeconds: clipboardSeconds,
      ));
    } catch (e) {
      emit(SettingsError('Failed to load settings: $e'));
    }
  }

  void _onSetClipboardClearDuration(SetClipboardClearDuration event, Emitter<SettingsState> emit) async {
    if (state is SettingsLoaded) {
      final currentState = state as SettingsLoaded;
      
      await _storageService.settingsBox.put('clipboardClearSeconds', event.seconds);
      _clipboardService.updateDuration(Duration(seconds: event.seconds));
      
      emit(currentState.copyWith(clipboardClearSeconds: event.seconds));
    }
  }

  void _onToggleTheme(ToggleTheme event, Emitter<SettingsState> emit) async {
    if (state is SettingsLoaded) {
      final currentState = state as SettingsLoaded;
      final newDarkMode = !currentState.isDarkMode;
      
      await _storageService.settingsBox.put('isDarkMode', newDarkMode);
      emit(currentState.copyWith(isDarkMode: newDarkMode));
    }
  }


  void _onSetAutoLockDuration(SetAutoLockDuration event, Emitter<SettingsState> emit) async {
    if (state is SettingsLoaded) {
      final currentState = state as SettingsLoaded;
      
      await _storageService.settingsBox.put('autoLockMinutes', event.minutes);
      _authBloc.setAutoLockMinutes(event.minutes);
      
      emit(currentState.copyWith(autoLockMinutes: event.minutes));
    }
  }

  void _onExportProject(ExportProjectEvent event, Emitter<SettingsState> emit) async {
    try {
      await _exportService.exportProject(event.projectId);
    } catch (e) {
      // Could emit an error or handle via a separate channel
    }
  }

  void _onImportEnvFile(ImportEnvFile event, Emitter<SettingsState> emit) async {
    try {
      await _exportService.importEnvFile(event.filePath, event.projectId);
      // Need to tell SecretBloc to reload to show newly imported ones
      _secretBloc.add(LoadSecrets(event.projectId));
    } catch (e) {
      // Handled via UI ideally
    }
  }
}
