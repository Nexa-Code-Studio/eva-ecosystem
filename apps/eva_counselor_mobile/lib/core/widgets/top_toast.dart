import 'package:flutter/material.dart';

enum ToastType { success, warning, error, info }

class TopToast {
  static void show(
    BuildContext context, {
    required String message,
    String? title,
    ToastType type = ToastType.success,
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    Color bg;
    Color iconColor;
    IconData icon;

    switch (type) {
      case ToastType.success:
        bg = const Color(0xFF1B5E20);
        iconColor = Colors.white;
        icon = Icons.check_circle_rounded;
        break;
      case ToastType.warning:
        bg = const Color(0xFFE65100);
        iconColor = Colors.white;
        icon = Icons.warning_rounded;
        break;
      case ToastType.error:
        bg = const Color(0xFFB71C1C);
        iconColor = Colors.white;
        icon = Icons.error_rounded;
        break;
      case ToastType.info:
        bg = const Color(0xFF303F9F);
        iconColor = Colors.white;
        icon = Icons.info_rounded;
        break;
    }

    entry = OverlayEntry(
      builder: (context) => _TopToastWidget(
        title: title,
        message: message,
        backgroundColor: bg,
        icon: icon,
        iconColor: iconColor,
        onDismiss: () => entry.remove(),
      ),
    );

    overlay.insert(entry);
  }
}

class _TopToastWidget extends StatefulWidget {
  final String? title;
  final String message;
  final Color backgroundColor;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onDismiss;

  const _TopToastWidget({
    this.title,
    required this.message,
    required this.backgroundColor,
    required this.icon,
    required this.iconColor,
    required this.onDismiss,
  });

  @override
  State<_TopToastWidget> createState() => _TopToastWidgetState();
}

class _TopToastWidgetState extends State<_TopToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _offsetAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _offsetAnim = Tween<Offset>(
      begin: const Offset(0, -0.6),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);

    _ctrl.forward();

    // Auto dismiss after 2.8 seconds
    Future.delayed(const Duration(milliseconds: 2800), () {
      if (mounted) {
        _ctrl.reverse().then((_) => widget.onDismiss());
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      top: topPadding + 10,
      left: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _offsetAnim,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: widget.backgroundColor,
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(widget.icon, color: widget.iconColor, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.title != null) ...[
                          Text(
                            widget.title!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                        ],
                        Text(
                          widget.message,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
