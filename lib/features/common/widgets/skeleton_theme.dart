import 'package:skeletonizer/skeletonizer.dart';

const kFaioSkeletonEffect = ShimmerEffect(
  baseColor: Color(0xFFE0E2E8),
  highlightColor: Color(0xFFF6F7FB),
  begin: AlignmentDirectional(-1.0, -0.35),
  end: AlignmentDirectional(1.0, 0.35),
  duration: Duration(milliseconds: 1600),
);
