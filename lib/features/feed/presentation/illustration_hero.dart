import 'package:flutter/widgets.dart';

String illustrationHeroTag(String id) => 'illustration-hero-$id';

Tween<Rect?> illustrationHeroRectTween(Rect? begin, Rect? end) {
  return RectTween(begin: begin, end: end);
}
