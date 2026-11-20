import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/store.dart';
import '../core/theme.dart';

/// بطاقة عضوية احترافية مرسومة بالكامل (بدون صور جاهزة)
/// تصميم: بنفسجي عميق + خطوط ذهبية + شعار النادي
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

class _MemberCardFlipState extends State<MemberCardFlip> with SingleTickerProviderStateMixin {
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
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: _toggle,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final angle = _controller.value * math.pi;
              final showFront = angle < math.pi / 2;
              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0011)
                  ..rotateY(angle),
                child: showFront
                    ? _Front(member: widget.member)
                    : Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.rotationY(math.pi),
                        child: _Back(member: widget.member),
                      ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.threesixty, size: 15, color: AppColors.muted.withValues(alpha: 0.9)),
            const SizedBox(width: 6),
            Text(
              'اضغط على البطاقة لقلبها',
              style: TextStyle(fontSize: 12, color: AppColors.muted.withValues(alpha: 0.9)),
            ),
          ],
        ),
      ],
    );
  }
}

// ── هيكل البطاقة المشترك ────────────────────────────────────────────────
class _CardShell extends StatelessWidget {
  final Widget child;
  const _CardShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.586, // مقاس بطاقة مصرفية
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2A0A4E).withValues(alpha: 0.35),
              blurRadius: 30,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // الخلفية المتدرّجة
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [Color(0xFF22103C), Color(0xFF3E1478), Color(0xFF1C0B33)],
                    stops: [0.0, 0.55, 1.0],
                  ),
                ),
              ),
              // زخارف هندسية دقيقة
              CustomPaint(painter: _GuillochePainter()),
              // إطار ذهبي مزدوج
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFC9A227).withValues(alpha: 0.85), width: 1.2),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(17),
                      border: Border.all(color: const Color(0xFFEBD08A).withValues(alpha: 0.22), width: 0.8),
                    ),
                  ),
                ),
              ),
              Padding(padding: const EdgeInsets.fromLTRB(14, 12, 14, 10), child: child),
            ],
          ),
        ),
      ),
    );
  }
}

/// زخارف أمنية تشبه خطوط الوثائق الرسمية (Guilloche)
class _GuillochePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gold = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..color = const Color(0xFFEBD08A).withValues(alpha: 0.10);

    // أقواس متراكزة في الزاوية اليسرى السفلى
    for (var i = 0; i < 16; i++) {
      final r = 26.0 + i * 11;
      canvas.drawCircle(Offset(-10, size.height + 8), r, gold);
    }

    // أقواس في الزاوية اليمنى العليا
    final gold2 = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..color = const Color(0xFFC9A227).withValues(alpha: 0.08);
    for (var i = 0; i < 12; i++) {
      canvas.drawCircle(Offset(size.width + 14, -12), 30.0 + i * 13, gold2);
    }

    // مونوغرام مائي في الوسط
    final tp = TextPainter(
      text: TextSpan(
        text: 'EPC',
        style: TextStyle(
          color: const Color(0xFFEBD08A).withValues(alpha: 0.055),
          fontSize: size.height * 0.55,
          fontWeight: FontWeight.w900,
          letterSpacing: 4,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas.save();
    canvas.translate((size.width - tp.width) / 2, (size.height - tp.height) / 2);
    tp.paint(canvas, Offset.zero);
    canvas.restore();

    // خطوط قطرية خفيفة
    final line = Paint()
      ..strokeWidth = 0.5
      ..color = Colors.white.withValues(alpha: 0.035);
    for (var x = -size.height; x < size.width; x += 7) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), line);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// شعار النادي داخل دائرة بيضاء
class _LogoMark extends StatelessWidget {
  final double size;
  const _LogoMark({this.size = 30});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.07),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFC9A227), width: 1),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: ClipOval(child: Image.asset('assets/images/logo.png', fit: BoxFit.contain)),
    );
  }
}

/// رقاقة البطاقة الذكية
class _Chip extends StatelessWidget {
  final double width;
  final double height;
  const _Chip({this.width = 26, this.height = 20});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF3DE9B), Color(0xFFC9A227), Color(0xFFE8CC7A)],
        ),
      ),
      child: CustomPaint(painter: _ChipPainter()),
    );
  }
}

class _ChipPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFF8A6A12).withValues(alpha: 0.55)
      ..strokeWidth = 0.8;
    canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), p);
    canvas.drawLine(Offset(size.width / 2, 0), Offset(size.width / 2, size.height), p);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.22, size.height * 0.22, size.width * 0.56, size.height * 0.56),
        const Radius.circular(2),
      ),
      p,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── الوجه الأمامي ───────────────────────────────────────────────────────
class _Front extends StatelessWidget {
  final Member member;
  const _Front({required this.member});

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: LayoutBuilder(
        builder: (context, c) {
          final s = (c.maxWidth / 340).clamp(0.72, 1.6);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── الترويسة ──
              Row(
                children: [
                  _LogoMark(size: 30 * s),
                  SizedBox(width: 8 * s),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'نادي رواد الاقتصاد',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12.5 * s,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                          ),
                        ),
                        Text(
                          'ECONOMICS PIONEERS CLUB',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: const Color(0xFFEBD08A),
                            fontSize: 6.2 * s,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 7 * s, vertical: 3 * s),
                    decoration: BoxDecoration(
                      color: const Color(0xFFC9A227).withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFC9A227).withValues(alpha: 0.6)),
                    ),
                    child: Text(
                      member.year,
                      style: TextStyle(
                        color: const Color(0xFFEBD08A),
                        fontSize: 7.5 * s,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8 * s),
              // ── الجسم ──
              Expanded(
                child: LayoutBuilder(
                  builder: (context, bc) {
                    final photoH = bc.maxHeight - 24 * s;
                    final photoW = photoH * 0.72;
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── الصورة + الرقاقة ──
                        SizedBox(
                          width: photoW,
                          child: Column(
                            children: [
                              Container(
                                height: photoH,
                                width: photoW,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(9 * s),
                                  border: Border.all(color: const Color(0xFFC9A227), width: 1.6),
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [Color(0x33FFFFFF), Color(0x14FFFFFF)],
                                  ),
                                ),
                                child: Padding(
                                  padding: EdgeInsets.all(1.6 * s),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8.5 * s),
                                    child: _Photo(member: member, iconSize: photoH * 0.30),
                                  ),
                                ),
                              ),
                              SizedBox(height: 6 * s),
                              _Chip(width: 24 * s, height: 18 * s),
                            ],
                          ),
                        ),
                        SizedBox(width: 12 * s),
                        // ── البيانات ──
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    member.fullName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14.5 * s,
                                      fontWeight: FontWeight.w800,
                                      height: 1.2,
                                    ),
                                  ),
                                  SizedBox(height: 3 * s),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 6 * s, vertical: 2.4 * s),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFC9A227).withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(4 * s),
                                      border: Border.all(
                                          color: const Color(0xFFC9A227).withValues(alpha: 0.45),
                                          width: 0.8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.verified_user_outlined,
                                            size: 8.6 * s, color: const Color(0xFFEBD08A)),
                                        SizedBox(width: 3 * s),
                                        Text(
                                          'رقم التسجيل  ${member.regNumber}',
                                          style: TextStyle(
                                            color: const Color(0xFFEBD08A),
                                            fontSize: 8.8 * s,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.6,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 6 * s),
                              Expanded(
                                child: Column(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: _Field(
                                          label: 'التخصص',
                                          value: member.displaySpecialization,
                                          s: s,
                                          maxLines: 2),
                                    ),
                                    SizedBox(height: 3.5 * s),
                                    Expanded(
                                      child: _Field(
                                          label: 'المستوى الدراسي',
                                          value: member.level,
                                          s: s),
                                    ),
                                    SizedBox(height: 3.5 * s),
                                    Expanded(
                                      flex: 2,
                                      child: _Field(
                                          label: 'الكلية',
                                          value: member.branch,
                                          s: s,
                                          maxLines: 2),
                                    ),
                                    if (member.phone.isNotEmpty) ...[
                                      SizedBox(height: 3.5 * s),
                                      Expanded(
                                        child: _Field(
                                            label: 'الهاتف', value: member.phone, s: s),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              SizedBox(height: 4 * s),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              // ── التذييل ──
              Row(
                children: [
                  Text(
                    'بطاقة عضو',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontSize: 8.5 * s,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '  •  MEMBER CARD',
                    style: TextStyle(
                      color: const Color(0xFFEBD08A).withValues(alpha: 0.75),
                      fontSize: 6.4 * s,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.event_available_outlined,
                            size: 7.6 * s, color: Colors.white.withValues(alpha: 0.42)),
                        SizedBox(width: 3 * s),
                        Flexible(
                          child: Text(
                            'عضو منذ ${member.joinedLabel} • ${member.role}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.45),
                              fontSize: 6.4 * s,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final String value;
  final double s;
  final int maxLines;

  const _Field({required this.label, required this.value, required this.s, this.maxLines = 1});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 8 * s, vertical: 3.6 * s),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.085),
        borderRadius: BorderRadius.circular(5 * s),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10), width: 0.8),
      ),
      child: Row(
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: const Color(0xFFEBD08A).withValues(alpha: 0.8),
              fontSize: 7.4 * s,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
          SizedBox(width: 7 * s),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.start,
              style: TextStyle(
                color: Colors.white,
                fontSize: 10 * s,
                fontWeight: FontWeight.w800,
                height: 1.15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── الوجه الخلفي ────────────────────────────────────────────────────────
class _Back extends StatelessWidget {
  final Member member;
  const _Back({required this.member});

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: LayoutBuilder(
        builder: (context, c) {
          final s = (c.maxWidth / 340).clamp(0.72, 1.6);
          final qrSize = math.min(c.maxHeight * 0.62, c.maxWidth * 0.34);

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
                      fontSize: 9.5 * s,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'EPC • ${member.year}',
                    style: TextStyle(
                      color: const Color(0xFFEBD08A).withValues(alpha: 0.8),
                      fontSize: 6.5 * s,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 5 * s),
              Container(
                height: 4.2 * s,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3 * s),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFC9A227), Color(0xFFEBD08A), Color(0xFFC9A227)],
                  ),
                ),
              ),
              SizedBox(height: 7 * s),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: qrSize,
                          height: qrSize,
                          padding: EdgeInsets.all(qrSize * 0.075),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(qrSize * 0.10),
                            border: Border.all(color: const Color(0xFFC9A227), width: 1.1),
                          ),
                          child: QrBlock(member: member),
                        ),
                        SizedBox(height: 3 * s),
                        Text(
                          'امسح للتحقق',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 6 * s,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(width: 12 * s),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            member.fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12.5 * s,
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                            ),
                          ),
                          Text(
                            member.regNumber,
                            style: TextStyle(
                              color: const Color(0xFFEBD08A),
                              fontSize: 10 * s,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.4,
                            ),
                          ),
                          SizedBox(height: 5 * s),
                          Container(height: 0.8, color: Colors.white.withValues(alpha: 0.15)),
                          SizedBox(height: 5 * s),
                          _line('التخصص', member.displaySpecialization, s),
                          _line('المستوى', member.level, s),
                          _line('الصفة', member.role, s),
                          if (member.phone.isNotEmpty) _line('الهاتف', member.phone, s),
                          if (member.email.isNotEmpty) _line('البريد', member.email, s),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 4 * s),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    flex: 5,
                    child: SizedBox(
                      height: 15 * s,
                      child: CustomPaint(painter: _BarcodePainter(member.regNumber)),
                    ),
                  ),
                  SizedBox(width: 10 * s),
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          height: 12 * s,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.88),
                            borderRadius: BorderRadius.circular(2 * s),
                          ),
                          child: Text(
                            'توقيع العضو',
                            style: TextStyle(
                              color: const Color(0xFF2A0A4E),
                              fontSize: 5.6 * s,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        SizedBox(height: 2 * s),
                        Text(
                          'EPC • ${DateTime.now().year}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.3),
                            fontSize: 5 * s,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 3 * s),
              Text(
                'هذه البطاقة ملك لنادي رواد الاقتصاد — غير قابلة للتحويل',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.32),
                  fontSize: 5.6 * s,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _line(String label, String value, double s) {
    return Padding(
      padding: EdgeInsets.only(bottom: 2.6 * s),
      child: Row(
        children: [
          SizedBox(
            width: 34 * s,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: const Color(0xFFEBD08A).withValues(alpha: 0.8),
                fontSize: 7 * s,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.95),
                fontSize: 8 * s,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
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
      color: Colors.white.withValues(alpha: 0.10),
      alignment: Alignment.center,
      child: Icon(
        Icons.person,
        size: iconSize,
        color: Colors.white.withValues(alpha: 0.45),
      ),
    );
  }
}

/// QR مع حماية من الأخطاء
class QrBlock extends StatelessWidget {
  final Member member;
  const QrBlock({super.key, required this.member});

  @override
  Widget build(BuildContext context) {
    final payload = 'EPC|${member.regNumber}|${member.fullName}|${member.displaySpecialization}';
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


/// باركود مرسوم من رقم التسجيل (للمظهر المهني فقط)
class _BarcodePainter extends CustomPainter {
  final String data;
  _BarcodePainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    final seed = data.isEmpty ? 1234567 : data.codeUnits.fold<int>(0, (a, b) => a * 31 + b);
    final rnd = math.Random(seed);
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.9);
    var x = 0.0;
    var i = 0;
    while (x < size.width) {
      final w = (0.6 + rnd.nextDouble() * 1.8);
      if (i.isEven) {
        paint.color = Colors.white.withValues(alpha: 0.55 + rnd.nextDouble() * 0.4);
        canvas.drawRect(
          Rect.fromLTWH(x, 0, w, size.height - 1.5),
          paint,
        );
      }
      x += w + 0.8 + rnd.nextDouble() * 1.6;
      i++;
    }
  }

  @override
  bool shouldRepaint(covariant _BarcodePainter old) => old.data != data;
}
