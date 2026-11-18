import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../clock/clock_engine.dart';
import '../../../../../clock/flip_palette.dart';

const _flipFont = 'SFProRoundedBold';
const _flipDuration = Duration(milliseconds: 1000);

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
    // 参考样式：正方形卡片、小号粗体数字、日期行居中在上、秒卡悬挂分卡右下。
    final cardSize = landscape ? 260.0 : 210.0;
    final gap = cardSize * 0.07;
    final dateSize = cardSize * 0.055;
    final dateGap = cardSize * 0.08;
    final secSize = cardSize * 0.14;
    final secOverflow = cardSize * 0.05;
    final dateColor = Color.lerp(palette.digit, Colors.white, 0.75)!;

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
              right: -secOverflow,
              bottom: -secOverflow,
              child: _FlipCard(
                value: snapshot.displaySecond,
                size: secSize,
                palette: palette,
              ),
            ),
        ],
      ),
    ];

    return Semantics(
      container: true,
      label: snapshot.timeLabel,
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.contain,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (snapshot.showDate) ...[
                    Text(
                      snapshot.dateLabel,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: dateColor,
                        fontFamily: _flipFont,
                        fontSize: dateSize,
                        fontWeight: FontWeight.w700,
                        height: 1,
                        letterSpacing: 1.0,
                      ),
                    ),
                    SizedBox(height: dateGap),
                  ],
                  Flex(
                    direction: landscape ? Axis.horizontal : Axis.vertical,
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: cards,
                  ),
                ],
              ),
            ),
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
  });

  final String value;
  final double size;
  final FlipPalette palette;
  final String? badge;

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
        final eased = (1 - math.cos(math.pi * raw)) / 2;
        final topPhase = eased < 0.5;
        final topAngle = math.min(eased * math.pi, math.pi / 2);
        final bottomAngle = math.max(eased * math.pi - math.pi, -math.pi / 2);
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
                        Column(
                          children: [
                            _half(_current, top: true),
                            _half(
                              flipping ? _previous : _current,
                              top: false,
                            ),
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
                              value: _current,
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
        color: top ? widget.palette.cardTop : widget.palette.cardBottom,
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
                      fontSize: widget.size * 0.71,
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
