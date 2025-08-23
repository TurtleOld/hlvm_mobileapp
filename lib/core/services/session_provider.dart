import 'package:flutter/material.dart';
import 'package:hlvm_mobileapp/core/services/session_manager.dart';

class SessionProvider extends InheritedWidget {
  final SessionManager sessionManager;

  const SessionProvider({
    super.key,
    required this.sessionManager,
    required super.child,
  });

  static SessionProvider of(BuildContext context) {
    final SessionProvider? result =
        context.dependOnInheritedWidgetOfExactType<SessionProvider>();
    assert(result != null, 'No SessionProvider found in context');
    return result!;
  }

  static SessionManager? maybeOf(BuildContext context) {
    final SessionProvider? result =
        context.dependOnInheritedWidgetOfExactType<SessionProvider>();
    return result?.sessionManager;
  }

  /// Безопасный доступ к SessionManager с fallback
  static SessionManager? safeOf(BuildContext context) {
    try {
      return maybeOf(context);
    } catch (e) {
      return null;
    }
  }

  /// Проверка доступности SessionProvider в контексте
  static bool hasSessionProvider(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<SessionProvider>() !=
        null;
  }

  @override
  bool updateShouldNotify(SessionProvider oldWidget) {
    return sessionManager != oldWidget.sessionManager;
  }
}
