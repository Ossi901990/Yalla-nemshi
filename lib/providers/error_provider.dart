import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_exception.dart';

/// State class for tracking errors in operations
class ErrorState {
  final AppException? error;
  final bool isError;

  ErrorState({
    this.error,
  }) : isError = error != null;

  factory ErrorState.initial() => ErrorState(error: null);

  ErrorState copyWith({AppException? error}) {
    return ErrorState(error: error);
  }

  ErrorState clearError() => ErrorState(error: null);
}

/// Notifier for managing error state
class ErrorNotifier extends StateNotifier<ErrorState> {
  ErrorNotifier() : super(ErrorState.initial());

  void setError(AppException error) {
    state = state.copyWith(error: error);
  }

  void clearError() {
    state = state.clearError();
  }
}

/// Provider for global error state
final errorStateProvider = StateNotifierProvider<ErrorNotifier, ErrorState>((ref) {
  return ErrorNotifier();
});

/// Convenience provider to check if there's an error
final hasErrorProvider = Provider<bool>((ref) {
  final errorState = ref.watch(errorStateProvider);
  return errorState.isError;
});

/// Get the current error message
final errorMessageProvider = Provider<String?>((ref) {
  final errorState = ref.watch(errorStateProvider);
  return errorState.error?.message;
});

/// Wrap an async operation with error handling
Future<T?> executeWithErrorHandling<T>(
  Ref ref,
  Future<T> Function() operation,
) async {
  try {
    final result = await operation();
    // Clear error on success
    ref.read(errorStateProvider.notifier).clearError();
    return result;
  } on AppException catch (e) {
    ref.read(errorStateProvider.notifier).setError(e);
    return null;
  } catch (e) {
    final error = AppError(
      message: e.toString(),
      originalError: e,
    );
    ref.read(errorStateProvider.notifier).setError(error);
    return null;
  }
}
