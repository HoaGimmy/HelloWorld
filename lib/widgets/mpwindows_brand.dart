import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class MPWindowsBrandHeader extends StatelessWidget {
  final bool compact;
  const MPWindowsBrandHeader({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'MP WINDOWS - Trung thực dẫn đầu - cửa sáng bền lâu.',
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        child: Padding(
          padding: EdgeInsets.all(compact ? 12 : 18),
          child: Column(
            children: [
              SvgPicture.asset(
                'assets/branding/mpwindows_logo.svg',
                height: compact ? 72 : 104,
                fit: BoxFit.contain,
              ),
              if (!compact) ...[
                const SizedBox(height: 8),
                Text(
                  'Trung thực dẫn đầu - cửa sáng bền lâu.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF8A5A00),
                      ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class MPWindowsSplashScreen extends StatefulWidget {
  const MPWindowsSplashScreen({super.key});

  @override
  State<MPWindowsSplashScreen> createState() => _MPWindowsSplashScreenState();
}

class _MPWindowsSplashScreenState extends State<MPWindowsSplashScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 1100), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/home');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C1A32),
      body: SizedBox.expand(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.asset(
                  'assets/branding/mpwindows_logo_dark.svg',
                  width: MediaQuery.sizeOf(context).width * 0.88,
                  fit: BoxFit.fitWidth,
                ),
                const SizedBox(height: 18),
                Text(
                  'Trung thực dẫn đầu - cửa sáng bền lâu.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: const Color(0xFFFFD965),
                      ),
                ),
                const SizedBox(height: 28),
                const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFFD965)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
