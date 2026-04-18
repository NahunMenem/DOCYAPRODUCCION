import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class DocYaBottomNav extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;
  final bool isHomeStyle;

  const DocYaBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
    this.isHomeStyle = false,
  });

  @override
  Widget build(BuildContext context) {
    const activeColor = Color(0xFF14B8A6);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final activeGradient = isHomeStyle
        ? const LinearGradient(
            colors: [
              Color(0xFF0EA896),
              Color(0xFF14B8A6),
              Color(0xFF5EEAD4),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : LinearGradient(
            colors: isDark
                ? const [
                    Color(0xFF153B40),
                    Color(0xFF14B8A6),
                  ]
                : const [
                    Color(0xFFE8FCF8),
                    Color(0xFFD3F7F0),
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
    final navGradient = isHomeStyle
        ? LinearGradient(
            colors: isDark
                ? const [
                    Color(0xFF08161D),
                    Color(0xFF0E2831),
                  ]
                : const [
                    Color(0xFFFFFFFF),
                    Color(0xFFF4FFFC),
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : LinearGradient(
            colors: isDark
                ? const [
                    Color(0xFF0B171D),
                    Color(0xFF13242C),
                  ]
                : const [
                    Color(0xFFFDFEFE),
                    Color(0xFFF7FBFB),
                  ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          );

    final items = [
      {'icon': PhosphorIconsFill.house, 'label': 'Inicio'},
      {'icon': PhosphorIconsFill.note, 'label': 'Recetas'},
      {'icon': PhosphorIconsFill.stethoscope, 'label': 'Consultas'},
      {'icon': PhosphorIconsFill.user, 'label': 'Más'},
    ];

    if (isHomeStyle) {
      return SafeArea(
        minimum: EdgeInsets.fromLTRB(
          18,
          0,
          18,
          bottomInset > 0 ? 10 : 16,
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.34 : 0.12),
                blurRadius: 30,
                spreadRadius: 2,
                offset: const Offset(0, 14),
              ),
              BoxShadow(
                color: activeColor.withOpacity(isDark ? 0.10 : 0.05),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF10242B).withOpacity(0.78)
                      : Colors.white.withOpacity(0.82),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withOpacity(0.10)
                        : const Color(0xFF14B8A6).withOpacity(0.12),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  child: Row(
                    children: List.generate(items.length, (index) {
                      final item = items[index];
                      final isActive = selectedIndex == index;

                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () => onItemTapped(index),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOutCubic,
                              constraints: const BoxConstraints(minHeight: 62),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 9,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                gradient: isActive ? activeGradient : null,
                                color: isActive
                                    ? null
                                    : (isDark
                                        ? Colors.white.withOpacity(0.025)
                                        : const Color(0xFFF7FCFC)
                                            .withOpacity(0.35)),
                                border: Border.all(
                                  color: isActive
                                      ? Colors.white.withOpacity(0.14)
                                      : Colors.transparent,
                                ),
                                boxShadow: isActive
                                    ? [
                                        BoxShadow(
                                          color: activeColor.withOpacity(0.22),
                                          blurRadius: 18,
                                          offset: const Offset(0, 6),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  AnimatedScale(
                                    scale: isActive ? 1.05 : 1.0,
                                    duration:
                                        const Duration(milliseconds: 220),
                                    curve: Curves.easeOutBack,
                                    child: Icon(
                                      item['icon'] as IconData,
                                      size: isActive ? 23 : 21,
                                      color: isActive
                                          ? Colors.white
                                          : (isDark
                                              ? Colors.white70
                                              : const Color(0xFF5B6770)),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      item['label'] as String,
                                      maxLines: 1,
                                      style: GoogleFonts.manrope(
                                        color: isActive
                                            ? Colors.white
                                            : (isDark
                                                ? Colors.white70
                                                : const Color(0xFF5B6770)),
                                        fontSize: 11,
                                        fontWeight: isActive
                                            ? FontWeight.w800
                                            : FontWeight.w600,
                                        letterSpacing: 0.15,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.fromLTRB(
        8,
        6,
        8,
        bottomInset > 0 ? bottomInset : 8,
      ),
      decoration: BoxDecoration(
        gradient: navGradient,
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withOpacity(0.08)
                : const Color(0xFF14B8A6).withOpacity(0.10),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.18 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: List.generate(items.length, (index) {
          final item = items[index];
          final isActive = selectedIndex == index;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => onItemTapped(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  constraints: const BoxConstraints(
                    minHeight: 54,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: isActive ? activeGradient : null,
                    color: isActive
                        ? null
                        : (isDark
                            ? Colors.white.withOpacity(0.015)
                            : Colors.transparent),
                    border: Border.all(
                      color: isActive
                          ? activeColor.withOpacity(isDark ? 0.28 : 0.14)
                          : Colors.transparent,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedScale(
                        scale: isActive ? 1.05 : 1.0,
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutBack,
                        child: Icon(
                          item['icon'] as IconData,
                          size: isActive ? 22 : 20,
                          color: isActive
                              ? activeColor
                              : (isDark
                                  ? Colors.white70
                                  : const Color(0xFF5B6770)),
                        ),
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          item['label'] as String,
                          maxLines: 1,
                          style: GoogleFonts.manrope(
                            color: isActive
                                ? activeColor
                                : (isDark
                                    ? Colors.white70
                                    : const Color(0xFF5B6770)),
                            fontSize: 10.5,
                            fontWeight:
                                isActive ? FontWeight.w800 : FontWeight.w600,
                            letterSpacing: 0.15,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
