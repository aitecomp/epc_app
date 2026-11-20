import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/store.dart';
import '../core/theme.dart';

/// بطاقة العضو مبنية على قالب النادي الرسمي (member_card.png — 1336×910)
/// مع طباعة بيانات العضو فوق الحقول الفارغة في القالب.
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
                    ? _CardFront(member: widget.member)
                    : Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.rotationY(math.pi),
                        child: _CardBack(member: widget.member),
                      ),
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.threesixty, size: 16, color: AppColors.muted),
            const SizedBox(width: 6),
            Text(
              'اضغط على البطاقة لقلبها',
              style: TextStyle(fontSize: 12.5, color: AppColors.muted.withValues(alpha: 0.95)),
            ),
          ],
        ),
      ],
    );
  }
}

class _CardFront extends StatelessWidget {
  final Member member;
  const _CardFront({required this.member});

  static const double _w = 1336;
  static const double _h = 910;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: _w / _h,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final s = constraints.maxWidth / _w;
          Widget field(String value, double top, {double right = 1095}) {
            return Positioned(
              left: 483 * s,
              top: top * s,
              width: (right - 483) * s,
              height: 64 * s,
              child: Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: EdgeInsets.only(right: 12 * s),
                  child: Text(
                    value.isEmpty ? '—' : value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 46 * s,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF2A0A4E),
                    ),
                  ),
                ),
              ),
            );
          }

          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: AppColors.plum.withValues(alpha: 0.30),
                  blurRadius: 34,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset('assets/images/member_card.png', fit: BoxFit.fill),
                  // صندوق الصورة
                  Positioned(
                    left: 72 * s,
                    top: 292 * s,
                    width: 344 * s,
                    height: 410 * s,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18 * s),
                      child: _MemberPhoto(member: member, radius: 18 * s),
                    ),
                  ),
                  field(member.firstName, 294),
                  field(member.lastName, 389),
                  field(member.displaySpecialization, 484),
                  field(member.level, 576, right: 1012),
                  field(member.year, 668, right: 1012),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CardBack extends StatelessWidget {
  final Member member;
  const _CardBack({required this.member});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1336 / 910,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: const LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Color(0xFF2A0A4E), Color(0xFF4B1E8C), Color(0xFF2A0A4E)],
          ),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.55), width: 1.4),
          boxShadow: [
            BoxShadow(
              color: AppColors.plum.withValues(alpha: 0.30),
              blurRadius: 34,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: Stack(
          children: [
            // زخرفة ذهبية خفيفة
            Positioned(
              left: -40,
              bottom: -60,
              child: Container(
                width: 190,
                height: 190,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [AppColors.gold.withValues(alpha: 0.18), Colors.transparent],
                  ),
                ),
              ),
            ),
            LayoutBuilder(
              builder: (context, c) {
                final w = c.maxWidth;
                final h = c.maxHeight;
                final qrSize = math.min(h * 0.76, w * 0.40);
                final pad = w * 0.045;

                return Padding(
                  padding: EdgeInsets.all(pad),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // ── رمز QR الكبير ──
                      Container(
                        width: qrSize,
                        height: qrSize,
                        padding: EdgeInsets.all(qrSize * 0.085),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(qrSize * 0.12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 14,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: QifiOrGap(member: member),
                      ),
                      SizedBox(width: w * 0.035),
                      // ── البيانات بجانب الرمز ──
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'نادي رواد الاقتصاد',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.goldSoft.withValues(alpha: 0.85),
                                fontSize: h * 0.042,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            ),
                            SizedBox(height: h * 0.006),
                            Text(
                              member.fullName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: h * 0.095,
                                fontWeight: FontWeight.w800,
                                height: 1.2,
                              ),
                            ),
                            SizedBox(height: h * 0.012),
                            Row(
                              children: [
                                Icon(Icons.badge_outlined,
                                    size: h * 0.055, color: AppColors.goldSoft),
                                SizedBox(width: w * 0.012),
                                Flexible(
                                  child: Text(
                                    member.regNumber,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: AppColors.goldSoft,
                                      fontSize: h * 0.065,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.1,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: h * 0.022),
                            Container(height: 1, color: Colors.white.withValues(alpha: 0.18)),
                            SizedBox(height: h * 0.018),
                            _row('التخصص', member.displaySpecialization, h, w),
                            _row('المستوى', member.level, h, w),
                            _row('السنة', member.year, h, w),
                            _row('الصفة', member.role, h, w),
                            if (member.phone.isNotEmpty) _row('الهاتف', member.phone, h, w),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            // شعار صغير
            Positioned(
              left: 10,
              top: 8,
              child: Opacity(
                opacity: 0.85,
                child: Text(
                  'EPC',
                  style: TextStyle(
                    color: AppColors.gold.withValues(alpha: 0.55),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, double h, double w) {
    return Padding(
      padding: EdgeInsets.only(bottom: h * 0.008),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: w * 0.17,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.goldSoft.withValues(alpha: 0.9),
                fontSize: h * 0.046,
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
                color: Colors.white,
                fontSize: h * 0.05,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// QR مع حماية من الأخطاء
class QifiOrGap extends StatelessWidget {
  final Member member;
  const QifiOrGap({super.key, required this.member});

  @override
  Widget build(BuildContext context) {
    final payload = 'EPC|${member.regNumber}|${member.fullName}|${member.specialization}';
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

class _MemberPhoto extends StatelessWidget {
  final Member member;
  final double radius;
  const _MemberPhoto({required this.member, required this.radius});

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
      color: const Color(0xFFDAD6EA),
      alignment: Alignment.center,
      child: Icon(Icons.person, size: 46, color: AppColors.purple.withValues(alpha: 0.45)),
    );
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
