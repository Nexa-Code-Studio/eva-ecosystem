import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

class FloatingNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final VoidCallback? onCenterTap;
  final Key? centerButtonKey;
  final Key? journalTabKey;
  final Key? trenTabKey;
  final Key? careTabKey;

  const FloatingNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.onCenterTap,
    this.centerButtonKey,
    this.journalTabKey,
    this.trenTabKey,
    this.careTabKey,
  });

  int _getSlotForIndex(int index) {
    switch (index) {
      case 0:
        return 0;
      case 1:
        return 1;
      case 2:
        return 3;
      case 3:
        return 4;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeSlot = _getSlotForIndex(currentIndex);

    return Stack(
      alignment: Alignment.bottomCenter,
      clipBehavior: Clip.none,
      children: [
        // Main Floating Nav Bar Container
        Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          height: 68,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.12),
                blurRadius: 24,
                spreadRadius: 0,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                spreadRadius: 0,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.borderSoft, width: 1.2),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final slotWidth = constraints.maxWidth / 5.0;
                final pillWidth = slotWidth - 8.0;
                final pillHeight = 52.0;
                final pillTop = (constraints.maxHeight - pillHeight) / 2.0;
                final pillLeft = (activeSlot * slotWidth) + 4.0;

                return Stack(
                  children: [
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      left: pillLeft,
                      top: pillTop,
                      width: pillWidth,
                      height: pillHeight,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            flex: 1,
                            child: _buildSideNavItem(
                              index: 0,
                              iconUnselected: Icons.home_outlined,
                              iconSelected: Icons.home,
                              label: 'Beranda',
                            ),
                          ),
                          Expanded(
                            key: journalTabKey,
                            flex: 1,
                            child: _buildSideNavItem(
                              index: 1,
                              iconUnselected: Icons.menu_book_outlined,
                              iconSelected: Icons.menu_book,
                              label: 'Jurnal',
                            ),
                          ),
                          const Expanded(flex: 1, child: SizedBox()),
                          Expanded(
                            key: trenTabKey,
                            flex: 1,
                            child: _buildSideNavItem(
                              index: 2,
                              iconUnselected: Icons.show_chart_outlined,
                              iconSelected: Icons.show_chart,
                              label: 'Tren',
                            ),
                          ),
                          Expanded(
                            key: careTabKey,
                            flex: 1,
                            child: _buildSideNavItem(
                              index: 3,
                              iconUnselected: Icons.volunteer_activism_outlined,
                              iconSelected: Icons.volunteer_activism,
                              label: 'Layanan',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),

        // Central Voice Session Action Button
        Positioned(
          bottom: 30,
          child: Semantics(
            button: true,
            label: 'Mulai sesi suara EVA',
            child: Tooltip(
              message: 'Sesi Suara EVA',
              child: GestureDetector(
                key: centerButtonKey,
                onTap:
                    onCenterTap ??
                    () {
                      Navigator.pushNamed(context, '/chat');
                    },
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [AppColors.primaryLight, AppColors.primary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        blurRadius: 18,
                        spreadRadius: 1,
                        offset: const Offset(0, 6),
                      ),
                    ],
                    border: Border.all(color: Colors.white, width: 3.0),
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: Colors.white,
                    size: 25,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSideNavItem({
    required int index,
    required IconData iconUnselected,
    required IconData iconSelected,
    required String label,
  }) {
    final isSelected = currentIndex == index;
    final activeColor = AppColors.primary;
    final inactiveColor = AppColors.textSecondary;

    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TweenAnimationBuilder<Color?>(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                tween: ColorTween(
                  begin: isSelected ? inactiveColor : activeColor,
                  end: isSelected ? activeColor : inactiveColor,
                ),
                builder: (context, color, child) {
                  return Icon(
                    isSelected ? iconSelected : iconUnselected,
                    size: 22,
                    color: color,
                  );
                },
              ),
              const SizedBox(height: 3),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? activeColor : inactiveColor,
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
