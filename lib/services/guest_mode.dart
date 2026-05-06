import 'package:flutter/material.dart';

class GuestMode {
  GuestMode._();
  static final GuestMode instance = GuestMode._();

  final ValueNotifier<bool> active = ValueNotifier<bool>(false);

  bool get isActive => active.value;

  void enable() => active.value = true;
  void disable() => active.value = false;
}

bool guestBlocked(BuildContext context, {String? feature}) {
  if (!GuestMode.instance.isActive) return false;
  final String message = feature == null
      ? 'You need an account to use this feature. Please log in to continue.'
      : 'You need an account to use $feature. Please log in to continue.';
  showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        icon: Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            color: Color(0xFFEEF0FB),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.lock_outline_rounded,
            color: Color(0xFF5E72E4),
            size: 28,
          ),
        ),
        title: const Text(
          'Login required',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Text(message, textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Not now'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              GuestMode.instance.disable();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5E72E4),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Log in'),
          ),
        ],
      );
    },
  );
  return true;
}