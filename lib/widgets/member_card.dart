import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/store.dart';
import '../core/theme.dart';

// ══════════════════════════════════════════════════════════════════════════
//  بطاقة عضوية نادي رواد الاقتصاد — تصميم مرسوم بالكامل
//  ألوان: بنفسجي عميق + ذهبي · خطوط رفيعة · تدرّج ضوئي · شعار النادي
// ══════════════════════════════════════════════════════════════════════════

const Color _kGold = Color(0xFFC9A227);
const Color _kGoldSoft = Color(0xFFEBD08A);

/// نمط ألوان داخلي للبطاقة
class _C {
  static const deep = Color(0xFF1B0A2E);
  static const mid = Color(0xFF3F1273);
  static const dark = Color(0xFF120620);
  static const gold = _kGold;
  static const goldSoft = _kGoldSoft;
}

/// بطاقة قابلة للقلب بين الوجهين
class MemberCardFlip extends StatefulWidget {
  final Member member;
  final bool initiallyFlipped;

  const MemberCardFlip({
    super.key,
    required this.member,
    this.initiallyFlipped = false,
  });

  @override
  State<MemberCardFlip> createState() => _MemberCardFlipState();
}

class _MemberCardFlipState extends State<MemberCardFlip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
      value: widget.initiallyFlipped ? 1 : 0,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_controller.value < 0.5) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggle,
      child: AspectRatio(
        aspectRatio: 1.586,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value;
            final showBack = t >= 0.5;
            // زاوية محدودة (٧٦°) حتى تبقى البطاقة ظاهرة دائماً
            const maxAngle = 76 * math.pi / 180;
            final local = showBack ? (t - 0.5) * 2 : t * 2; // 0..1
            final angle = showBack ? (1 - local) * maxAngle : -local * maxAngle;
            final depth = 1 - 0.05 * math.sin(local * math.pi);

            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0016)
                ..scaleByDouble(depth, depth, 1, 1)
                ..rotateY(angle),
              child: showBack ? _Back(member: widget.member) : _Front(member: widget.member),
            );
          },
        ),
      ),
    );
  }
}

// ── الهيكل العام (خلفية + إطار) ─────────────────────────────────────────
class _CardShell extends StatelessWidget {
  final Widget content;
  final Widget? band;

  const _CardShell({required this.content, this.band});

  @override
  Widget build(BuildContext context) {
    const radius = 27.0;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1B0A2E).withValues(alpha: 0.42),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: LayoutBuilder(
          builder: (context, c) {
            final bandH = band == null ? 0.0 : c.maxHeight * 0.19;
            return Stack(
              fit: StackFit.expand,
              children: [
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_C.deep, _C.mid, _C.dark],
                      stops: [0.0, 0.52, 1.0],
                    ),
                  ),
                ),
                CustomPaint(painter: _DecorPainter()),
                if (band != null)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: bandH,
                    child: _FrostedBand(child: band!),
                  ),
                // إطار ذهبي رفيع
                Padding(
                  padding: const EdgeInsets.all(9),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(19),
                      border: Border.all(
                        color: _C.gold.withValues(alpha: 0.30),
                        width: 0.9,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(20, 17, 20, band == null ? 16 : bandH + 8),
                  child: content,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// شريط سفلي بخلفية مغبشة من صورة النادي
class _FrostedBand extends StatelessWidget {
  final Widget child;
  const _FrostedBand({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // الصورة مغبشة + تلوين بنفسجي + تلاشي ناعم للأعلى
          ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (rect) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.white, Colors.white],
              stops: [0.0, 0.38, 1.0],
            ).createShader(rect),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ImageFiltered(
                  imageFilter:
                      ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6, tileMode: TileMode.mirror),
                  child: Transform.scale(
                    scale: 1.6,
                    child: Image.asset(
                      'assets/images/club_banner.png',
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x992B0B4D), Color(0xCC150722)],
                      stops: [0.0, 1.0],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // محتوى الشريط
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 11),
            child: Align(alignment: Alignment.bottomCenter, child: child),
          ),
        ],
      ),
    );
  }
}

/// زخرفة الخلفية: هالات ضوئية + أقواس رفيعة + خطوط مائلة دقيقة
class _DecorPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // هالة ذهبية خلف الصورة (يمين)
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          _C.gold.withValues(alpha: 0.16),
          _C.gold.withValues(alpha: 0.0),
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.80, size.height * 0.46),
          radius: size.width * 0.34,
        ),
      );
    canvas.drawCircle(
      Offset(size.width * 0.80, size.height * 0.46),
      size.width * 0.34,
      glow,
    );

    // هالة بنفسجية فاتحة (يسار سفلي)
    final glow2 = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF8B4BF0).withValues(alpha: 0.30),
          const Color(0xFF8B4BF0).withValues(alpha: 0.0),
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.16, size.height * 0.95),
          radius: size.width * 0.42,
        ),
      );
    canvas.drawCircle(
      Offset(size.width * 0.16, size.height * 0.95),
      size.width * 0.42,
      glow2,
    );

    // لمعة قطرية خفيفة (تأثير معدني)
    final sheenRect = Rect.fromLTWH(-size.width * 0.1, -size.height, size.width * 0.9, size.height * 2.4);
    final sheen = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0x00FFFFFF), Color(0x14FFFFFF), Color(0x00FFFFFF)],
        stops: [0.32, 0.5, 0.68],
      ).createShader(sheenRect);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), sheen);

    // أقواس رفيعة (زاوية سفلية يسرى)
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..color = _C.goldSoft.withValues(alpha: 0.13);
    for (var i = 0; i < 14; i++) {
      canvas.drawCircle(Offset(-size.width * 0.04, size.height + 10), 22.0 + i * 13, arc);
    }

    // أقواس أعلى اليمين
    final arc2 = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..color = _C.gold.withValues(alpha: 0.10);
    for (var i = 0; i < 9; i++) {
      canvas.drawCircle(Offset(size.width + 12, -18), 34.0 + i * 15, arc2);
    }

    // خطوط مائلة شديدة الخفوت
    final line = Paint()
      ..strokeWidth = 0.6
      ..color = Colors.white.withValues(alpha: 0.022);
    for (var x = -size.height; x < size.width; x += 9) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), line);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// شعار النادي داخل دائرة
class _LogoMark extends StatelessWidget {
  final double size;
  const _LogoMark({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: _C.gold.withValues(alpha: 0.75), width: 1.1),
      ),
      padding: EdgeInsets.all(size * 0.10),
      child: ClipOval(
        child: Image.asset(
          'assets/images/logo.png',
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          errorBuilder: (_, __, ___) => Center(
            child: Text(
              'EPC',
              style: TextStyle(
                color: _C.mid,
                fontWeight: FontWeight.w900,
                fontSize: size * 0.28,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// خط فاصل رفيع
class _Rule extends StatelessWidget {
  final double s;
  final double alpha;
  const _Rule({required this.s, this.alpha = 0.14});

  @override
  Widget build(BuildContext context) => Container(
        height: 0.8,
        width: double.infinity,
        color: Colors.white.withValues(alpha: alpha),
      );
}

// ══════════════════════════════════════════════════════════════════════════
//  الوجه الأمامي
// ══════════════════════════════════════════════════════════════════════════
class _Front extends StatelessWidget {
  final Member member;
  const _Front({required this.member});

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      content: LayoutBuilder(
        builder: (context, c) {
          final s = (c.maxWidth / 310).clamp(0.70, 3.2);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── الترويسة ──────────────────────────────────────────────
              Row(
                children: [
                  _LogoMark(size: 25 * s),
                  SizedBox(width: 7 * s),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'نادي رواد الاقتصاد',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11.6 * s,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                          letterSpacing: -0.1,
                        ),
                      ),
                      SizedBox(height: 1.5 * s),
                      Text(
                        'ECONOMICS PIONEERS CLUB',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _C.goldSoft.withValues(alpha: 0.85),
                          fontSize: 5.4 * s,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.3,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 7 * s, vertical: 3.2 * s),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _C.gold.withValues(alpha: 0.45),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      member.year,
                      style: TextStyle(
                        color: _C.goldSoft,
                        fontSize: 6.6 * s,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 9 * s),
              _Rule(s: s, alpha: 0.16),
              SizedBox(height: 11 * s),

              // ── الجسم ────────────────────────────────────────────────
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            member.fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17 * s,
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                              letterSpacing: -0.2,
                            ),
                          ),
                          SizedBox(height: 3.5 * s),
                          Text(
                            member.branch,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _C.goldSoft.withValues(alpha: 0.72),
                              fontSize: 8.2 * s,
                              fontWeight: FontWeight.w600,
                              height: 1.15,
                            ),
                          ),
                          SizedBox(height: 7 * s),
                          Row(
                            children: [
                              Container(
                                width: 3 * s,
                                height: 9 * s,
                                decoration: BoxDecoration(
                                  color: _C.gold,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              SizedBox(width: 5 * s),
                              Text(
                                'رقم التسجيل',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.48),
                                  fontSize: 7 * s,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(width: 5 * s),
                              Text(
                                member.regNumber,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11.2 * s,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.6,
                                  height: 1.1,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          // شريط البيانات
                          _Rule(s: s, alpha: 0.10),
                          SizedBox(height: 5 * s),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 5,
                                child: _Spec(
                                  label: 'التخصص',
                                  value: member.displaySpecialization,
                                  s: s,
                                  maxLines: 2,
                                ),
                              ),
                              _VLine(s: s),
                              Expanded(
                                flex: 4,
                                child: _Spec(
                                  label: 'المستوى',
                                  value: member.level,
                                  s: s,
                                  maxLines: 2,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 6 * s),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 5,
                                child: _Spec(
                                  label: 'الصفة',
                                  value: member.role,
                                  s: s,
                                  maxLines: 1,
                                ),
                              ),
                              if (member.phone.isNotEmpty) ...[
                                _VLine(s: s),
                                Expanded(
                                  flex: 4,
                                  child: _Spec(
                                    label: 'الهاتف',
                                    value: member.phone,
                                    s: s,
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 13 * s),
                    _PhotoFrame(member: member, s: s),
                  ],
                ),
              ),

            ],
          );
        },
      ),
      band: LayoutBuilder(
        builder: (context, bc) {
          final bs = (bc.maxWidth / 320).clamp(0.70, 3.2);
          return Row(
            children: [
              Text(
                'MEMBER CARD',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 5.6 * bs,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.0,
                ),
              ),
              const Spacer(),
              Text(
                'عضو منذ ${member.joinedLabel}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 6.4 * bs,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _VLine extends StatelessWidget {
  final double s;
  const _VLine({required this.s});

  @override
  Widget build(BuildContext context) => Container(
        width: 0.8,
        height: 20 * s,
        margin: EdgeInsets.symmetric(horizontal: 7 * s),
        color: Colors.white.withValues(alpha: 0.16),
      );
}

class _Spec extends StatelessWidget {
  final String label;
  final String value;
  final double s;
  final int maxLines;

  const _Spec({
    required this.label,
    required this.value,
    required this.s,
    this.maxLines = 2,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: _C.goldSoft.withValues(alpha: 0.68),
            fontSize: 6.4 * s,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
            height: 1.1,
          ),
        ),
        SizedBox(height: 2.4 * s),
        Text(
          value.isEmpty ? '—' : value,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.95),
            fontSize: 9 * s,
            fontWeight: FontWeight.w700,
            height: 1.15,
          ),
        ),
      ],
    );
  }
}

/// إطار الصورة
class _PhotoFrame extends StatelessWidget {
  final Member member;
  final double s;
  const _PhotoFrame({required this.member, required this.s});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final h = c.maxHeight;
        final w = math.min(h * 0.74, c.maxWidth);
        return SizedBox(
          width: w,
          height: h,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11 * s),
              border: Border.all(
                color: _C.gold.withValues(alpha: 0.55),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 12 * s,
                  offset: Offset(0, 5 * s),
                ),
              ],
            ),
            padding: EdgeInsets.all(1.6 * s),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9.5 * s),
              child: _Photo(member: member, iconSize: h * 0.22),
            ),
          ),
        );
      },
    );
  }
}

class _Photo extends StatelessWidget {
  final Member member;
  final double iconSize;
  const _Photo({required this.member, this.iconSize = 34});

  @override
  Widget build(BuildContext context) {
    if (member.photoBase64.isNotEmpty) {
      try {
        return Image.memory(
          base64Decode(member.photoBase64),
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          gaplessPlayback: true,
        );
      } catch (_) {}
    }
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x33FFFFFF), Color(0x14FFFFFF)],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        member.firstName.isNotEmpty
            ? member.firstName.substring(0, 1)
            : member.initials,
        style: TextStyle(
          color: _C.goldSoft.withValues(alpha: 0.62),
          fontSize: iconSize * 1.5,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
//  الوجه الخلفي
// ══════════════════════════════════════════════════════════════════════════
class _Back extends StatelessWidget {
  final Member member;
  const _Back({required this.member});

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      content: LayoutBuilder(
        builder: (context, c) {
          final s = (c.maxWidth / 310).clamp(0.70, 3.2);
          final qrSize = math.min(c.maxHeight * 0.56, c.maxWidth * 0.32);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _LogoMark(size: 20 * s),
                  SizedBox(width: 6 * s),
                  Text(
                    'نادي رواد الاقتصاد',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9.8 * s,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'EPC  ·  ${member.year}',
                    style: TextStyle(
                      color: _C.goldSoft.withValues(alpha: 0.8),
                      fontSize: 6.2 * s,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8 * s),
              _Rule(s: s, alpha: 0.16),
              SizedBox(height: 9 * s),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // QR
                    Column(
                      children: [
                        Container(
                          width: qrSize,
                          height: qrSize,
                          padding: EdgeInsets.all(qrSize * 0.07),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(qrSize * 0.09),
                            border: Border.all(
                              color: _C.gold.withValues(alpha: 0.55),
                              width: 0.9,
                            ),
                          ),
                          child: QrBlock(member: member),
                        ),
                        SizedBox(height: 4 * s),
                        Text(
                          'امسح للتحقق',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.45),
                            fontSize: 5.6 * s,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(width: 14 * s),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            member.fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12.5 * s,
                              fontWeight: FontWeight.w800,
                              height: 1.15,
                            ),
                          ),
                          SizedBox(height: 1.5 * s),
                          Text(
                            member.regNumber,
                            style: TextStyle(
                              color: _C.goldSoft,
                              fontSize: 10 * s,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.4,
                            ),
                          ),
                          SizedBox(height: 5 * s),
                          _InfoLine(label: 'التخصص', value: member.displaySpecialization, s: s),
                          _InfoLine(label: 'المستوى', value: member.level, s: s),
                          _InfoLine(label: 'الصفة', value: member.role, s: s),
                          if (member.phone.isNotEmpty)
                            _InfoLine(label: 'الهاتف', value: member.phone, s: s),
                          if (member.email.isNotEmpty)
                            _InfoLine(label: 'البريد', value: member.email, s: s),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      band: LayoutBuilder(
        builder: (context, bc) {
          final bs = (bc.maxWidth / 320).clamp(0.70, 3.2);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                flex: 4,
                child: SizedBox(
                  height: 12 * bs,
                  child: CustomPaint(painter: _BarcodePainter(member.regNumber)),
                ),
              ),
              SizedBox(width: 12 * bs),
              Expanded(
                flex: 3,
                child: Text(
                  'هذه البطاقة ملك لنادي رواد الاقتصاد — غير قابلة للتحويل',
                  maxLines: 2,
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.42),
                    fontSize: 4.9 * bs,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final String label;
  final String value;
  final double s;
  const _InfoLine({required this.label, required this.value, required this.s});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 2.0 * s),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.07),
            width: 0.7,
          ),
        ),
      ),
      child: Row(
        children: [
          Text(
            label,
            maxLines: 1,
            style: TextStyle(
              color: _C.goldSoft.withValues(alpha: 0.68),
              fontSize: 6.4 * s,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(width: 8 * s),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.92),
                fontSize: 7.8 * s,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// باركود مرسوم من رقم التسجيل (مظهر مهني)
class _BarcodePainter extends CustomPainter {
  final String data;
  _BarcodePainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    final seed = data.isEmpty ? 1234567 : data.codeUnits.fold<int>(0, (a, b) => a * 31 + b);
    final rnd = math.Random(seed);
    final paint = Paint();
    var x = 0.0;
    var i = 0;
    while (x < size.width) {
      final w = 0.6 + rnd.nextDouble() * 1.7;
      if (i.isEven) {
        paint.color = Colors.white.withValues(alpha: 0.55 + rnd.nextDouble() * 0.4);
        canvas.drawRect(Rect.fromLTWH(x, 0, w, size.height - 1.5), paint);
      }
      x += w + 0.8 + rnd.nextDouble() * 1.5;
      i++;
    }
  }

  @override
  bool shouldRepaint(covariant _BarcodePainter old) => old.data != data;
}

// ══════════════════════════════════════════════════════════════════════════
//  عناصر مساعدة
// ══════════════════════════════════════════════════════════════════════════
/// QR مع حماية من الأخطاء
class QrBlock extends StatelessWidget {
  final Member member;
  const QrBlock({super.key, required this.member});

  @override
  Widget build(BuildContext context) {
    final payload =
        'EPC|${member.regNumber}|${member.fullName}|${member.displaySpecialization}';
    try {
      return QrImageView(
        data: payload,
        version: QrVersions.auto,
        gapless: true,
        backgroundColor: Colors.white,
        padding: EdgeInsets.zero,
      );
    } catch (_) {
      return const Icon(Icons.qr_code_2, color: AppColors.plum);
    }
  }
}

/// صورة مصغّرة للأعضاء في القوائم
class MemberAvatar extends StatelessWidget {
  final Member member;
  final double size;
  const MemberAvatar({super.key, required this.member, this.size = 46});

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (member.photoBase64.isNotEmpty) {
      try {
        child = Image.memory(base64Decode(member.photoBase64), fit: BoxFit.cover);
      } catch (_) {
        child = _fallback();
      }
    } else {
      child = _fallback();
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.5), width: 1.6),
        color: AppColors.softViolet,
      ),
      child: ClipOval(child: SizedBox.expand(child: child)),
    );
  }

  Widget _fallback() => Container(
        color: AppColors.softViolet,
        alignment: Alignment.center,
        child: Text(
          member.initials,
          style: TextStyle(
            fontSize: size * 0.34,
            fontWeight: FontWeight.w800,
            color: AppColors.purple,
          ),
        ),
      );
}
