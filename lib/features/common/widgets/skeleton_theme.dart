import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

const _kFaioSkeletonBegin = AlignmentDirectional(-1.0, -0.35);
const _kFaioSkeletonEnd = AlignmentDirectional(1.0, 0.35);
const _kFaioSkeletonDuration = Duration(milliseconds: 1600);

const kFaioSkeletonEffect = ShimmerEffect(
  baseColor: Color(0xFFE0E2E8),
  highlightColor: Color(0xFFF6F7FB),
  begin: _kFaioSkeletonBegin,
  end: _kFaioSkeletonEnd,
  duration: _kFaioSkeletonDuration,
);

ShimmerEffect themedFaioSkeletonEffect(Color baseColor) {
  final highlight = Color.alphaBlend(Colors.white.withOpacity(0.18), baseColor);
  return ShimmerEffect(
    baseColor: baseColor,
    highlightColor: highlight,
    begin: _kFaioSkeletonBegin,
    end: _kFaioSkeletonEnd,
    duration: _kFaioSkeletonDuration,
  );
}
