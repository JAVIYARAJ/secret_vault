import 'package:equatable/equatable.dart';

abstract class SettingsState extends Equatable {
  const SettingsState();
  
  @override
  List<Object?> get props => [];
}

class SettingsInitial extends SettingsState {}

class SettingsLoaded extends SettingsState {
  final bool isDarkMode;
  final int autoLockMinutes;
  final int clipboardClearSeconds;
  final bool useBiometrics;

  const SettingsLoaded({
    required this.isDarkMode,
    required this.autoLockMinutes,
    required this.clipboardClearSeconds,
    required this.useBiometrics,
  });

  SettingsLoaded copyWith({
    bool? isDarkMode,
    int? autoLockMinutes,
    int? clipboardClearSeconds,
    bool? useBiometrics,
  }) {
    return SettingsLoaded(
      isDarkMode: isDarkMode ?? this.isDarkMode,
      autoLockMinutes: autoLockMinutes ?? this.autoLockMinutes,
      clipboardClearSeconds: clipboardClearSeconds ?? this.clipboardClearSeconds,
      useBiometrics: useBiometrics ?? this.useBiometrics,
    );
  }

  @override
  List<Object?> get props => [isDarkMode, autoLockMinutes, clipboardClearSeconds, useBiometrics];
}

class SettingsError extends SettingsState {
  final String message;

  const SettingsError(this.message);

  @override
  List<Object?> get props => [message];
}
