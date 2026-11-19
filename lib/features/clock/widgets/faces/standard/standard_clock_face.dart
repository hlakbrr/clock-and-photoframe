import 'package:flutter/material.dart';

import '../../../../../clock/clock_engine.dart';
import '../../../../../clock/bubble_palette.dart';
import '../../../../../clock/clock_theme.dart';
import '../../../../../clock/digital_theme.dart';
import '../../../../../clock/flip_palette.dart';
import 'standard_digital_clock_face.dart';
import '../bubble/bubble_clock_face.dart';
import 'standard_flip_clock_face.dart';
import 'standard_session_face.dart';

class StandardClockFace extends StatelessWidget {
  const StandardClockFace({
    super.key,
    required this.themeId,
    required this.digitalThemeId,
    required this.flipPaletteId,
    this.bubblePaletteId = BubblePaletteId.blue,
    this.nightMode = false,
    required this.snapshot,
    required this.landscape,
  });

  final ClockThemeId themeId;
  final DigitalThemeId digitalThemeId;
  final FlipPaletteId flipPaletteId;
  final BubblePaletteId bubblePaletteId;
  final bool nightMode;
  final ClockSnapshot snapshot;
  final bool landscape;

  @override
  Widget build(BuildContext context) {
    final digitalTheme = digitalThemeId.theme;
    final flipPalette = flipPaletteId.palette;
    final session = snapshot.session;
    if (session != null) {
      return StandardSessionFace(session: session, landscape: landscape);
    }
    return switch (themeId) {
      ClockThemeId.flip => StandardFlipClockFace(
        snapshot: snapshot,
        landscape: landscape,
        palette: flipPalette,
      ),
      ClockThemeId.digital => StandardDigitalClockFace(
        snapshot: snapshot,
        landscape: landscape,
        theme: digitalTheme,
      ),
      ClockThemeId.bubble => BubbleClockFace(
        snapshot: snapshot,
        palette: nightMode ? BubblePalette.night : bubblePaletteId.palette,
      ),
    };
  }
}
