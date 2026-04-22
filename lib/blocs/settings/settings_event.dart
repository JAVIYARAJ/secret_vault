import 'package:equatable/equatable.dart';

abstract class SettingsEvent extends Equatable {
  const SettingsEvent();

  @override
  List<Object?> get props => [];
}

class LoadSettings extends SettingsEvent {}

class ToggleTheme extends SettingsEvent {}

class SetAutoLockDuration extends SettingsEvent {
  final int minutes;

  const SetAutoLockDuration(this.minutes);

  @override
  List<Object?> get props => [minutes];
}

class ExportProjectEvent extends SettingsEvent {
  final String projectId;

  const ExportProjectEvent(this.projectId);

  @override
  List<Object?> get props => [projectId];
}

class ImportEnvFile extends SettingsEvent {
  final String filePath;
  final String projectId;

  const ImportEnvFile(this.filePath, this.projectId);

  @override
  List<Object?> get props => [filePath, projectId];
}
class SetClipboardClearDuration extends SettingsEvent {
  final int seconds;

  const SetClipboardClearDuration(this.seconds);

  @override
  List<Object?> get props => [seconds];
}

