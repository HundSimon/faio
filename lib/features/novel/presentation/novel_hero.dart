import 'package:flutter/widgets.dart';

String novelHeroTag(String id) => 'novel-hero-$id';

Tween<Rect?> novelHeroRectTween(Rect? begin, Rect? end) {
  return RectTween(begin: begin, end: end);
}
