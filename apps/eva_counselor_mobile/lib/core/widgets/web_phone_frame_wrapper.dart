import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class WebPhoneFrameWrapper extends StatelessWidget {
  final Widget child;

  const WebPhoneFrameWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return child;

    final mediaQuery = MediaQuery.of(context);
    if (mediaQuery.size.width <= 500) {
      return child;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2C),
      body: Center(
        child: Container(
          width: 420,
          height: 880,
          margin: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(48),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
            border: Border.all(color: const Color(0xFF333344), width: 3),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(44),
            child: child,
          ),
        ),
      ),
    );
  }
}
