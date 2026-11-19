import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../clock/clock_engine.dart';
import '../../../../../clock/flip_palette.dart';

const _flipFont = 'MPLUSRounded1c';
// Zen Flip Clock 风格：真实翻页钟两段式（旧页翻走露出新页），节奏快。
const _flipDuration = Duration(milliseconds: 550);

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
                          // 参考图秒卡下半比主卡深一档。
                          bottomColor: Color.lerp(
                            palette.cardBottom,
                            Colors.black,
                            0.18,
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
        // Zen 式两段时序：旧上半加速翻起（0~0.5），旧下半减速翻落（0.5~1）。
        final topPhase = raw < 0.5;
        final double p = topPhase ? raw / 0.5 : (raw - 0.5) / 0.5;
        final double eased =
            topPhase ? p * p : 1 - (1 - p) * (1 - p); // InQuad / OutQuad
        final angle = eased * (math.pi / 2);
        final topAngle = math.min(angle, math.pi / 2);
        final bottomAngle = math.max(-angle, -math.pi / 2);
        final radius = BorderRadius.circular(widget.size * 0.06);
        final width = widget.size;
        final height = widget.size;
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
                      clipBehavior: Clip.hardEdge,
                      children: [
                        // 新数字整卡垫底：旧页翻走时逐渐露出。
                        Column(
                          children: [
                            _half(_current, top: true),
                            _half(_current, top: false),
                          ],
                        ),
                        if (flipping && topPhase)
                          Align(
                            key: const ValueKey('flip-flap'),
                            alignment: Alignment.topCenter,
                            child: _flap(
                              value: _previous,
                              top: true,
                              angle: topAngle,
                            ),
                          ),
                        if (flipping && !topPhase)
                          Align(
                            key: const ValueKey('flip-flap'),
                            alignment: Alignment.bottomCenter,
                            child: _flap(
                              value: _previous,
                              top: false,
                              angle: bottomAngle,
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
    return Transform(
      alignment: top ? Alignment.bottomCenter : Alignment.topCenter,
      filterQuality: FilterQuality.medium,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.0028)
        ..rotateX(angle),
      child: _half(value, top: top),
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
