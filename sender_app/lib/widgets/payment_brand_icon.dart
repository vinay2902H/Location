import 'package:flutter/material.dart';
import 'withdrawal_dialog.dart';

/// A dedicated widget that renders the authentic brand icon for
/// payment providers (Paytm, PhonePe, Google Pay).
///
/// Loads the high-resolution official raster/vector assets from `assets/icons/`
/// with graceful, pixel-perfect native vector fallbacks if an asset is loading
/// or unavailable.
class PaymentBrandIcon extends StatelessWidget {
  final String methodId;
  final String? iconAsset;
  final double size;
  final double? borderRadius;
  final bool showShadow;

  const PaymentBrandIcon({
    super.key,
    required this.methodId,
    this.iconAsset,
    this.size = 48.0,
    this.borderRadius,
    this.showShadow = true,
  });

  /// Factory constructor to create directly from [WithdrawalMethodInfo]
  factory PaymentBrandIcon.fromMethod({
    Key? key,
    required WithdrawalMethodInfo method,
    double size = 48.0,
    double? borderRadius,
    bool showShadow = true,
  }) {
    return PaymentBrandIcon(
      key: key,
      methodId: method.id,
      iconAsset: method.iconAsset,
      size: size,
      borderRadius: borderRadius,
      showShadow: showShadow,
    );
  }

  String get _resolvedAssetPath {
    if (iconAsset != null && iconAsset!.isNotEmpty) {
      return iconAsset!;
    }
    switch (methodId.toLowerCase()) {
      case 'paytm':
        return 'assets/icons/paytm.png';
      case 'phonepe':
        return 'assets/icons/phonepe.png';
      case 'google_pay':
      case 'gpay':
        return 'assets/icons/gpay.png';
      default:
        return '';
    }
  }

  Color get _shadowColor {
    switch (methodId.toLowerCase()) {
      case 'paytm':
        return const Color(0xFF00B9F1).withAlpha(60);
      case 'phonepe':
        return const Color(0xFF5F259F).withAlpha(80);
      case 'google_pay':
      case 'gpay':
        return const Color(0xFF4285F4).withAlpha(60);
      default:
        return Colors.black26;
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = borderRadius ?? (size * 0.24);
    final assetPath = _resolvedAssetPath;

    Widget iconContent;
    if (assetPath.isNotEmpty) {
      iconContent = Image.asset(
        assetPath,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return _buildVectorFallback(effectiveRadius);
        },
      );
    } else {
      iconContent = _buildVectorFallback(effectiveRadius);
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(effectiveRadius),
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: _shadowColor,
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(effectiveRadius),
        child: iconContent,
      ),
    );
  }

  Widget _buildVectorFallback(double radius) {
    final id = methodId.toLowerCase();
    if (id == 'paytm') {
      return _buildPaytmFallback(radius);
    } else if (id == 'phonepe') {
      return _buildPhonePeFallback(radius);
    } else if (id == 'google_pay' || id == 'gpay') {
      return _buildGooglePayFallback(radius);
    }

    return Container(
      color: Colors.grey.shade800,
      alignment: Alignment.center,
      child: Icon(Icons.payment_rounded, size: size * 0.5, color: Colors.white),
    );
  }

  Widget _buildPhonePeFallback(double radius) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF6739B7), Color(0xFF5F259F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          'पे',
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.55,
            fontWeight: FontWeight.w900,
            fontFamily: 'sans-serif',
            height: 1.0,
          ),
        ),
      ),
    );
  }

  Widget _buildPaytmFallback(double radius) {
    return Container(
      width: size,
      height: size,
      color: Colors.white,
      padding: EdgeInsets.symmetric(horizontal: size * 0.08),
      child: Center(
        child: RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'Pay',
                style: TextStyle(
                  color: const Color(0xFF002970),
                  fontSize: size * 0.32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              TextSpan(
                text: 'tm',
                style: TextStyle(
                  color: const Color(0xFF00B9F1),
                  fontSize: size * 0.32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGooglePayFallback(double radius) {
    return Container(
      width: size,
      height: size,
      color: Colors.white,
      child: Center(
        child: CustomPaint(
          size: Size(size * 0.65, size * 0.65),
          painter: _GPayLoopPainter(),
        ),
      ),
    );
  }
}

/// Fallback painter for the iconic Google Pay multicolored loops
class _GPayLoopPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final paintBlue = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.22
      ..strokeCap = StrokeCap.round;

    final paintRed = Paint()
      ..color = const Color(0xFFEA4335)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.22
      ..strokeCap = StrokeCap.round;

    final paintYellow = Paint()
      ..color = const Color(0xFFFBBC04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.22
      ..strokeCap = StrokeCap.round;

    final paintGreen = Paint()
      ..color = const Color(0xFF34A853)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.22
      ..strokeCap = StrokeCap.round;

    // Draw interlocking loops
    final rectLeft = Rect.fromLTWH(w * 0.12, h * 0.15, w * 0.40, h * 0.70);
    final rectRight = Rect.fromLTWH(w * 0.48, h * 0.15, w * 0.40, h * 0.70);

    canvas.drawArc(rectLeft, 0.8, 3.14, false, paintBlue);
    canvas.drawArc(rectRight, -1.0, 2.5, false, paintRed);
    canvas.drawArc(rectRight, 1.5, 2.0, false, paintYellow);
    canvas.drawArc(rectLeft, 3.8, 1.8, false, paintGreen);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
