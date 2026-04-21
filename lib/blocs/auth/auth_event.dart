import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class SetMasterPassword extends AuthEvent {
  final String password;

  const SetMasterPassword(this.password);

  @override
  List<Object?> get props => [password];
}

class UnlockVault extends AuthEvent {
  final String password;

  const UnlockVault(this.password);

  @override
  List<Object?> get props => [password];
}

class LockVault extends AuthEvent {}

class CheckLockStatus extends AuthEvent {}

class ActivityDetected extends AuthEvent {}

class UpdateAutoLockDuration extends AuthEvent {
  final int minutes;
  const UpdateAutoLockDuration(this.minutes);

  @override
  List<Object?> get props => [minutes];
}
