import '../constants/app_strings.dart';

class ErrorHandler {
  static String getMessage(Object error) {
    final msg = error.toString().toLowerCase();
    print(msg);

    if (msg.contains('socketexception') ||
        msg.contains('network') ||
        msg.contains('connection refused') ||
        msg.contains('failed host lookup')) {
      return AppStrings.noInternet;
    }

    if (msg.contains('anthropic') ||
        msg.contains('claude') ||
        msg.contains('429') ||
        msg.contains('overloaded')) {
      return AppStrings.aiError;
    }

    if (msg.contains('invalid email')) {
      return 'Please enter a valid email address.';
    }

    if (msg.contains('invalid login') || msg.contains('invalid credentials')) {
      return 'Wrong email or password. Please try again.';
    }

    if (msg.contains('user already registered') ||
        msg.contains('already been registered')) {
      return 'An account with this email already exists. Please sign in.';
    }

    if (msg.contains('email not confirmed')) {
      return 'Please verify your email before signing in.';
    }

    if (msg.contains('password')) {
      return 'Password must be at least 6 characters.';
    }

    return AppStrings.genericError;
  }
}
