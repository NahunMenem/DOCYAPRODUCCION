import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../globals.dart';

class NoticiasCarousel extends StatefulWidget {
  const NoticiasCarousel({super.key});

  @override
  State<NoticiasCarousel> createState() => _NoticiasCarouselState();
}

class _NoticiasCarouselState extends State<NoticiasCarousel> {
  final PageController controller = PageController(viewportFraction: 0.9);

  final List<String> _fallbackUrls = const [
    'https://res.cloudinary.com/dqsacd9ez/image/upload/v1761172771/images_ullfix.jpg',
    'https://images.unsplash.com/photo-1579154204601-01588f351e67?auto=format&fit=crop&w=1200&q=80',
  ];

  List<String> noticiasUrls = [];
  int currentPage = 0;
  Timer? autoplayTimer;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    noticiasUrls = List<String>.from(_fallbackUrls);
    _cargarNoticias();
  }

  @override
  void dispose() {
    autoplayTimer?.cancel();
    controller.dispose();
    super.dispose();
  }

  Future<void> _cargarNoticias() async {
    try {
      final response = await http.get(Uri.parse('$API_URL/noticias'));
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final urls = (data['urls'] as List<dynamic>? ?? const [])
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toList();

        if (urls.isNotEmpty && mounted) {
          setState(() {
            noticiasUrls = urls;
            currentPage = 0;
          });
        }
      }
    } catch (_) {
      // Fallback silencioso: si falla Cloudinary o la red, queda el contenido base.
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        _iniciarAutoplay();
      }
    }
  }

  void _iniciarAutoplay() {
    autoplayTimer?.cancel();
    if (noticiasUrls.length <= 1) return;

    autoplayTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!controller.hasClients || noticiasUrls.isEmpty) return;
      final nextPage = (currentPage + 1) % noticiasUrls.length;
      controller.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_loading && noticiasUrls.isEmpty) {
      return const SizedBox(
        height: 220,
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFF14B8A6)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 220,
          child: PageView.builder(
            controller: controller,
            itemCount: noticiasUrls.length,
            onPageChanged: (index) => setState(() => currentPage = index),
            itemBuilder: (context, index) {
              final imageUrl = noticiasUrls[index];

              return AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                margin: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: index == currentPage ? 6 : 14,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              color: const Color(0xFF14B8A6),
                              value: progress.expectedTotalBytes != null
                                  ? progress.cumulativeBytesLoaded /
                                      (progress.expectedTotalBytes ?? 1)
                                  : null,
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.grey.shade300,
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.broken_image_outlined,
                            color: Colors.grey,
                            size: 40,
                          ),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.center,
                            colors: [
                              Colors.black.withOpacity(0.18),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(noticiasUrls.length, (index) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: currentPage == index ? 12 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: currentPage == index
                    ? const Color(0xFF14B8A6)
                    : (isDark ? Colors.white30 : Colors.black26),
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        ),
      ],
    );
  }
}
