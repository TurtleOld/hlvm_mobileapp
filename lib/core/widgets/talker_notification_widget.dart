import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/talker_bloc.dart';

class TalkerNotificationWidget extends StatelessWidget {
  const TalkerNotificationWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<TalkerBloc, TalkerState>(
      listener: (context, state) {
        if (state is TalkerNotification) {
          _showNotification(context, state);
        }
      },
      child: const SizedBox.shrink(),
    );
  }

  void _showNotification(
      BuildContext context, TalkerNotification notification) {
    Color backgroundColor;
    IconData icon;
    Duration duration;

    switch (notification.type) {
      case NotificationType.error:
        backgroundColor = Colors.red;
        icon = Icons.error;
        duration = const Duration(seconds: 5);
        break;
      case NotificationType.success:
        backgroundColor = Colors.green;
        icon = Icons.check_circle;
        duration = const Duration(seconds: 3);
        break;
      case NotificationType.warning:
        backgroundColor = Colors.orange;
        icon = Icons.warning;
        duration = const Duration(seconds: 4);
        break;
      case NotificationType.info:
        backgroundColor = Colors.blue;
        icon = Icons.info;
        duration = const Duration(seconds: 3);
        break;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                notification.message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        duration: duration,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        action: SnackBarAction(
          label: 'Закрыть',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }
}
