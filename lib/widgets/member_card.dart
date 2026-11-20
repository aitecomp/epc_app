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
                      fontSize: 40 * s,
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
                  field(member.specialization, 484),
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final s = constraints.maxWidth / 1336;
            final small = constraints.maxWidth < 360;
            return Padding(
              padding: EdgeInsets.all(20 * math.max(s, 0.5)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // QR
                  Container(
                    width: 108 * math.max(s, 0.62),
                    padding: EdgeInsets.all(8 * math.max(s, 0.62)),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: QifiOrGap(member: member),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'نادي رواد الاقتصاد',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: small ? 14 : 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'ECONOMICS PIONEERS CLUB',
                          style: TextStyle(
                            color: AppColors.goldSoft,
                            fontSize: small ? 8 : 9.5,
                            letterSpacing: 1.4,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _line('رقم التسجيل', member.regNumber, small),
                        _line('الهاتف', member.phone.isEmpty ? '—' : member.phone, small),
                        _line('البريد', member.email.isEmpty ? '—' : member.email, small),
                        _line('تاريخ الانضمام', member.joinedLabel, small),
                        _line('الصفة', member.role, small),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _line(String label, String value, bool small) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: small ? 78 : 92,
            child: Text(
              '$label:',
              style: TextStyle(
                color: AppColors.goldSoft,
                fontSize: small ? 9.5 : 11,
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
                fontSize: small ? 10 : 11.5,
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
