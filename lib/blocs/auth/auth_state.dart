import 'package:equatable/equatable.dart';

abstract class AuthState extends Equatable {
  const AuthState();
  
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLocked extends AuthState {
  final bool hasMasterPassword;

  const AuthLocked({required this.hasMasterPassword});

  @override
  List<Object?> get props => [hasMasterPassword];
}

class AuthUnlocked extends AuthState {}

class AuthError extends AuthState {
  final String message;

  const AuthError(this.message);

  @override
  List<Object?> get props => [message];
}
