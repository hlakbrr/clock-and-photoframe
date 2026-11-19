import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../clock/clock_engine.dart';
import '../../../../../clock/flip_palette.dart';

const _flipFont = 'MPLUSRounded1c';
// Zen Flip Clock 实测（51fps 录屏逐帧）：总时长约 210-250ms；
// 旧上半 0→180°（90° 后露出纯色背面、投影伸出卡框）；
// 旧下半随后 0→120° 垂挂（背面朝外）再淡出。
const _flipDuration = Duration(milliseconds: 250);

class StandardFlipClockFace extends StatelessWidget {
  const StandardFlipClockFace({
    super.key,
    required this.snapshot,
    required this.landscape,
    required this.palette,
  });

  final ClockSnapshot snapshot;
  final bool landscape;
  final FlipPalette palette;

  @override
  Widget build(BuildContext context) {
    // 参考图精确比例（2208x1242 实测取色取距）：
    // 卡 38.4% 屏宽 / 67.3% 屏高（正方形）；间隙 4.4% 卡宽；
    // 秒卡 25.9% 卡宽，右探出 10%、底探出 8%；圆角 6%；
    // 数字字号 70% 卡高；日期字号 5% 卡宽，中心距屏顶 7.6%，与数字同色 #B0B0B0。
    return Semantics(
      container: true,
      label: snapshot.timeLabel,
      child: ExcludeSemantics(
        child: SizedBox.expand(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final h = constraints.maxHeight;
              final cardSize = math.min(w * 0.384, h * 0.673).toDouble();
              final gap = cardSize * 0.044;
              final dateSize = cardSize * 0.050;
              final secSize = cardSize * 0.259;
              final secOverflowX = cardSize * 0.10;
              final secOverflowY = cardSize * 0.08;
              final dateColor = palette.digit;

              final cards = <Widget>[
                _FlipCard(
                  value: snapshot.displayHour,
                  size: cardSize,
                  palette: palette,
                  badge: snapshot.period,
                ),
                SizedBox(
                  width: landscape ? gap : 0,
                  height: landscape ? 0 : gap,
                ),
                // 分卡 + 悬挂在右下角外侧的秒卡（同素材缩小版，翻页动画一致）。
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _FlipCard(
                      value: snapshot.displayMinute,
                      size: cardSize,
                      palette: palette,
                    ),
                    if (snapshot.showSeconds)
                      Positioned(
                        right: -secOverflowX,
                        bottom: -secOverflowY,
                        child: _FlipCard(
                          value: snapshot.displaySecond,
                          size: secSize,
                          palette: palette,
                          // 参考图精确取色：秒卡下半 #1A1A1A（主卡下半
                          // #202020，加深系数 0.1875）；上半与主卡同色。
                          bottomColor: Color.lerp(
                            palette.cardBottom,
                            Colors.black,
                            0.1875,
                          ),
                        ),
                      ),
                  ],
                ),
              ];

              return Stack(
                children: [
                  // 卡片组：屏幕正中（上下左右对称留白）。
                  Center(
                    child: Flex(
                      direction: landscape ? Axis.horizontal : Axis.vertical,
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: cards,
                    ),
                  ),
                  // 日期：独立定位顶部，中心距屏顶 7.6% 屏高。
                  Positioned(
                    left: 0,
                    right: 0,
                    top: h * 0.076 - dateSize / 2,
                    child: Text(
                      snapshot.dateLabel,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: dateColor,
                        fontFamily: _flipFont,
                        fontSize: dateSize,
                        fontWeight: FontWeight.w800,
                        height: 1,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _FlipCard extends StatefulWidget {
  const _FlipCard({
    required this.value,
    required this.size,
    required this.palette,
    this.badge,
    this.topColor,
    this.bottomColor,
  });

  final String value;
  final double size;
  final FlipPalette palette;
  final String? badge;
  final Color? topColor;
  final Color? bottomColor;

  @override
  State<_FlipCard> createState() => _FlipCardState();
}

class _FlipCardState extends State<_FlipCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late String _current;
  late String _previous;

  @override
  void initState() {
    super.initState();
    _current = widget.value;
    _previous = widget.value;
    _controller = AnimationController(vsync: this, duration: _flipDuration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() => _previous = _current);
        }
      });
  }

  @override
  void didUpdateWidget(_FlipCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      _previous = oldWidget.value;
      _current = widget.value;
      if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
        _controller.stop();
        _controller.value = 1;
        _previous = _current;
      } else {
        _controller.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final raw = _controller.value;
        final flipping = _controller.isAnimating;
        final radius = BorderRadius.circular(widget.size * 0.06);
        final width = widget.size;
        final height = widget.size;

        // Zen 式时序（录屏实测）：
        // 0~0.5 旧上半 0→180°（easeOutQuad；90° 后露出纯色背面，投影可伸出卡框）；
        // 0.5~0.85 旧下半 0→100°（刚过垂直、垂页薄条）；
        // 0.75~1.0 垂页淡出（短命，避免遮挡新数字）。
        Widget? topFlap;
        Widget? bottomFlap;
        double hingeShadow = 0;
        if (flipping) {
          if (raw < 0.5) {
            final p = raw / 0.5;
            final a = (1 - (1 - p) * (1 - p)) * math.pi;
            if (a < math.pi * 0.97) {
              topFlap = _flap(value: _previous, top: true, angle: a);
            }
            hingeShadow = 0.45 * math.sin(p * math.pi);
          } else {
            final p = (raw - 0.5) / 0.5;
            final easedP = p < 0.5
                ? 2 * p * p
                : 1 - 2 * (1 - p) * (1 - p); // easeInOutQuad
            final a = easedP * (100 * math.pi / 180);
            final opacity = p > 0.75 ? 1 - (p - 0.75) / 0.25 : 1.0;
            bottomFlap = Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: _flap(value: _previous, top: false, angle: a),
            );
          }
        }

        return SizedBox(
          width: width,
          height: height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: height * 0.045,
                        spreadRadius: -height * 0.025,
                        offset: Offset(0, height * 0.015),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: radius,
                    child: Stack(
                      key: const ValueKey('flip-card-stack'),
                      fit: StackFit.expand,
                      children: [
                        // 新数字整卡垫底：旧页翻走时逐渐露出。
                        Column(
                          children: [
                            _half(_current, top: true),
                            _half(_current, top: false),
                          ],
                        ),
                        // 翻起页在中线处的投影（立体感）。
                        if (hingeShadow > 0)
                          Positioned(
                            top: height / 2 - height * 0.01,
                            left: 0,
                            right: 0,
                            child: Container(
                              height: height * 0.06,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black
                                        .withValues(alpha: hingeShadow),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        if (widget.badge != null)
                          Positioned(
                            left: width * 0.09,
                            top: height * 0.075,
                            child: Text(
                              widget.badge!,
                              key: const ValueKey('flip-period'),
                              style: TextStyle(
                                color: widget.palette.digit,
                                fontFamily: _flipFont,
                                fontSize: height * 0.12,
                                fontWeight: FontWeight.w700,
                                height: 1,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        Center(child: _divider()),
                      ],
                    ),
                  ),
                ),
              ),
              // 翻动页在裁剪层之外：3D 投影可伸出卡框（Zen 观感关键）。
              if (topFlap != null) Align(alignment: Alignment.topCenter, child: topFlap),
              if (bottomFlap != null) Align(alignment: Alignment.bottomCenter, child: bottomFlap),
            ],
          ),
        );
      },
    );
  }

  Widget _divider() {
    return Container(
      key: const ValueKey('flip-divider'),
      width: widget.size,
      height: math.max(1.5, widget.size * 0.008),
      decoration: BoxDecoration(
        color: widget.palette.divider,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: widget.size * 0.0015,
            offset: Offset(0, widget.size * 0.0005),
          ),
        ],
      ),
    );
  }

  Widget _flap({
    required String value,
    required bool top,
    required double angle,
  }) {
    // 超过 90° 后显示页背面（纯色，无数字）——Zen 观感关键。
    final showBack = math.cos(angle) < 0;
    final Widget content;
    if (showBack) {
      content = _halfBack(top);
    } else {
      final shade = top
          ? 0.10 + 0.16 * (angle / (math.pi / 2))
          : 0.12;
      content = ShaderMask(
        shaderCallback: (bounds) => LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: shade),
            Colors.black.withValues(alpha: shade * 0.3),
          ],
        ).createShader(bounds),
        blendMode: BlendMode.srcATop,
        child: _half(value, top: top),
      );
    }
    return Transform(
      alignment: top ? Alignment.bottomCenter : Alignment.topCenter,
      filterQuality: FilterQuality.medium,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.0045)
        ..rotateX(top ? angle : -angle),
      child: content,
    );
  }

  /// 页背面：纯色半页（比卡面略暗），翻过 90° 后可见。
  Widget _halfBack(bool top) {
    final base = top ? widget.palette.cardTop : widget.palette.cardBottom;
    final color = Color.lerp(base, Colors.black, 0.22)!;
    final radius = Radius.circular(widget.size * 0.06);
    return Container(
      width: widget.size,
      height: widget.size / 2,
      decoration: BoxDecoration(
        color: color,
        borderRadius: top
            ? BorderRadius.vertical(top: radius)
            : BorderRadius.vertical(bottom: radius),
      ),
    );
  }

  Widget _half(String value, {required bool top}) {
    final radius = Radius.circular(widget.size * 0.06);
    return Container(
      key: ValueKey(top ? 'flip-card-top' : 'flip-card-bottom'),
      width: widget.size,
      height: widget.size / 2,
      decoration: BoxDecoration(
        color: top
            ? (widget.topColor ?? widget.palette.cardTop)
            : (widget.bottomColor ?? widget.palette.cardBottom),
        borderRadius: top
            ? BorderRadius.vertical(top: radius)
            : BorderRadius.vertical(bottom: radius),
      ),
      child: ClipRRect(
        borderRadius: top
            ? BorderRadius.vertical(top: radius)
            : BorderRadius.vertical(bottom: radius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            OverflowBox(
              maxHeight: widget.size,
              alignment: top ? Alignment.topCenter : Alignment.bottomCenter,
              child: SizedBox(
                width: widget.size,
                height: widget.size,
                child: Center(
                  child: Text(
                    value,
                    style: TextStyle(
                      color: widget.palette.digit,
                      fontFamily: _flipFont,
                      fontSize: widget.size * 0.70,
                      fontWeight: FontWeight.w700,
                      height: 0.94,
                      letterSpacing: -widget.size * 0.012,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
