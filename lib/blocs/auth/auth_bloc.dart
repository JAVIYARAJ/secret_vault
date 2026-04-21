import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../services/storage_service.dart';
import '../../services/encryption_service.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final StorageService _storageService;
  final EncryptionService _encryptionService;
  Timer? _lockTimer;
  int _autoLockMinutes = 15; // Setup through settings later

  AuthBloc(this._storageService, this._encryptionService) : super(AuthInitial()) {
    on<CheckLockStatus>(_onCheckLockStatus);
    on<SetMasterPassword>(_onSetMasterPassword);
    on<UnlockVault>(_onUnlockVault);
    on<LockVault>(_onLockVault);
    on<ActivityDetected>(_onActivityDetected);
    on<UpdateAutoLockDuration>(_onUpdateAutoLockDuration);
  }

  void userActivityDetected() {
    add(ActivityDetected());
  }

  void setAutoLockMinutes(int minutes) {
    add(UpdateAutoLockDuration(minutes));
  }

  void _onUpdateAutoLockDuration(UpdateAutoLockDuration event, Emitter<AuthState> emit) {
    _autoLockMinutes = event.minutes;
    if (state is AuthUnlocked) {
      _startLockTimer();
    }
  }

  void _onActivityDetected(ActivityDetected event, Emitter<AuthState> emit) {
    if (state is AuthUnlocked) {
      _startLockTimer();
    }
  }

  void _startLockTimer() {
    _lockTimer?.cancel();
    if (_autoLockMinutes > 0) {
      _lockTimer = Timer(Duration(minutes: _autoLockMinutes), () {
        add(LockVault());
      });
    }
  }

  Future<void> _onCheckLockStatus(CheckLockStatus event, Emitter<AuthState> emit) async {
    final hash = await _storageService.getMasterPasswordHash();
    if (hash == null) {
      emit(const AuthLocked(hasMasterPassword: false));
    } else {
      emit(const AuthLocked(hasMasterPassword: true));
    }
  }

  Future<void> _onSetMasterPassword(SetMasterPassword event, Emitter<AuthState> emit) async {
    try {
      final hash = _encryptionService.hashPassword(event.password);
      await _storageService.saveMasterPasswordHash(hash);
      
      _encryptionService.initialize(event.password);
      emit(AuthUnlocked());
      _startLockTimer();
    } catch (e) {
       emit(AuthError('Failed to set master password: $e'));
    }
  }

  Future<void> _onUnlockVault(UnlockVault event, Emitter<AuthState> emit) async {
    try {
      final storedHash = await _storageService.getMasterPasswordHash();
      final inputHash = _encryptionService.hashPassword(event.password);

      if (storedHash == inputHash) {
        _encryptionService.initialize(event.password);
        emit(AuthUnlocked());
        _startLockTimer();
      } else {
        emit(const AuthError('Incorrect password'));
      }
    } catch (e) {
      emit(AuthError('Failed to unlock vault: $e'));
    }
  }

  void _onLockVault(LockVault event, Emitter<AuthState> emit) {
    _lockTimer?.cancel();
    _encryptionService.clear();
    emit(const AuthLocked(hasMasterPassword: true));
  }
}
