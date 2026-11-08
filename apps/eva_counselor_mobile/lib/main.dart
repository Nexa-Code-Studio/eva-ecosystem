import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/routes/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/web_phone_frame_wrapper.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: EvaCounselorApp()));
}

class EvaCounselorApp extends StatelessWidget {
  const EvaCounselorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EVA Counselor — Portal Psikolog',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: '/counselor-login',
      onGenerateRoute: AppRouter.onGenerateRoute,
      builder: (context, child) {
        return WebPhoneFrameWrapper(
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
