import 'dart:ui' as ui;

/// Records what the scene asks a canvas to draw, without drawing it. Colours
/// and geometry are kept; images are identified only by their size because a
/// wardrobe variant may or may not have finished preparing.
class RecordingCanvas implements ui.Canvas {
  final calls = <String>[];

  static String round(double value) => value.toStringAsFixed(5);

  static String _describe(Object? value) => switch (value) {
    final double number => round(number),
    final int number => '$number',
    final ui.Rect rect =>
      '[${round(rect.left)} ${round(rect.top)} '
          '${round(rect.right)} ${round(rect.bottom)}]',
    final ui.Offset offset => '(${round(offset.dx)} ${round(offset.dy)})',
    final ui.Image image => 'image:${image.width}x${image.height}',
    final ui.Paint paint => 'paint:${paint.color.toARGB32()}',
    _ => '${value.runtimeType}',
  };

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = invocation.memberName.toString().split('"')[1];
    calls.add(
      '$name ${invocation.positionalArguments.map(_describe).join(' ')}',
    );
    return name == 'getSaveCount' ? 1 : null;
  }
}
