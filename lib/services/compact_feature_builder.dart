import 'dart:math' as math;

import 'package:movenet_hands_bridge/movenet_hands_bridge.dart';

class CompactFeatureBuilder {
  CompactFeatureBuilder({
    this.sequenceLength = 24,
    this.activeThreshold = 0.12,
    List<double>? scalerMean,
    List<double>? scalerStd,
  })  : _scalerMean = scalerMean,
        _scalerStd = scalerStd;

  final int sequenceLength;
  final double activeThreshold;
  final List<double>? _scalerMean;
  final List<double>? _scalerStd;

  final List<LandmarkPacket> _buffer = <LandmarkPacket>[];

  void addPacket(LandmarkPacket packet) {
    _buffer.add(packet);
    if (_buffer.length > sequenceLength) {
      _buffer.removeAt(0);
    }
  }

  List<double>? buildFeatureVector() {
    if (_buffer.isEmpty) return null;

    final int frames = _buffer.length;
    final int seqLen = math.min(sequenceLength, frames);
    final List<LandmarkPacket> slice = _buffer.sublist(frames - seqLen, frames);

    final List<List<double>> pose = List<List<double>>.generate(
      seqLen,
      (index) => slice[index].pose,
      growable: false,
    );
    final List<List<double>> left =
        List<List<double>>.generate(seqLen, (index) => slice[index].leftHand);
    final List<List<double>> right =
        List<List<double>>.generate(seqLen, (index) => slice[index].rightHand);

    final _HandFeature leftFeat = _handFeatures(left, pose);
    final _HandFeature rightFeat = _handFeatures(right, pose);
    final List<double> shoulders = _shoulderFeatures(
      pose.last,
      _visibilityFrom(pose.last),
      left.last,
      right.last,
    );
    final List<double> confidences = _confidenceFeatures(
        _visibilityFrom(left.last), _visibilityFrom(right.last));
    final List<double> temporalStats = _temporalStats(
      _concatenateSeries(leftFeat.tipDists, rightFeat.tipDists),
      threshold: activeThreshold,
    );

    final List<double> featureVector = <double>[
      ...leftFeat.flatXY.last,
      ...rightFeat.flatXY.last,
      ...leftFeat.tipDists.last,
      ...rightFeat.tipDists.last,
      ...leftFeat.ratios.last,
      ...rightFeat.ratios.last,
      ...shoulders,
      ...confidences,
      ...temporalStats,
    ];

    return _applyScaler(featureVector);
  }

  List<double>? _applyScaler(List<double> raw) {
    final mean = _scalerMean;
    final std = _scalerStd;
    if (mean == null || std == null) {
      return raw;
    }
    if (mean.length != raw.length || std.length != raw.length) {
      return raw;
    }
    final List<double> scaled = List<double>.from(raw, growable: false);
    for (int i = 0; i < scaled.length; i++) {
      final double denom = std[i].abs() < 1e-6 ? 1.0 : std[i];
      scaled[i] = (scaled[i] - mean[i]) / denom;
    }
    return scaled;
  }

  List<double> _visibilityFrom(List<double> flattened) {
    final int count = flattened.length ~/ 4;
    final List<double> vis = List<double>.filled(count, 0.0);
    for (int i = 0; i < count; i++) {
      vis[i] = flattened[i * 4 + 3];
    }
    return vis;
  }
}

class _HandFeature {
  _HandFeature({
    required this.flatXY,
    required this.tipDists,
    required this.ratios,
  });

  final List<List<double>> flatXY;
  final List<List<double>> tipDists;
  final List<List<double>> ratios;
}

const List<int> _handPoints = <int>[0, 1, 4, 5, 8, 9, 12, 13, 16, 20];
const List<int> _tipPoints = <int>[4, 8, 12, 16, 20];
const List<int> _ratioPoints = <int>[8, 12, 16, 20];
const int _thumbTip = 4;
const int _thumbCmc = 1;
// MoveNet Thunder encodes keypoints in order; indices 5/6 map to left/right but coordinates are from camera view.
// MoveNet Thunder returns keypoints in viewer-centric order; swap if needed
const int _poseLeftShoulder = 5;
const int _poseRightShoulder = 6;

_HandFeature _handFeatures(List<List<double>> hand, List<List<double>> pose) {
  final int frames = hand.length;
  final List<List<double>> flatXY = <List<double>>[];
  final List<List<double>> tipDists = <List<double>>[];
  final List<List<double>> ratios = <List<double>>[];

  for (int f = 0; f < frames; f++) {
    final List<double> wrist = _coords(hand[f], 0);
    final List<double> leftShoulder =
        _coords(pose[f], _poseLeftShoulder, poseLandmark: true);
    final List<double> rightShoulder =
        _coords(pose[f], _poseRightShoulder, poseLandmark: true);
    final double shoulderDist = _norm3(
      leftShoulder[0] - rightShoulder[0],
      leftShoulder[1] - rightShoulder[1],
      leftShoulder[2] - rightShoulder[2],
    );

    final List<double> tipOffsetValues = <double>[];
    for (final int idx in _tipPoints) {
      final List<double> pt = _coords(hand[f], idx);
      tipOffsetValues.add(_norm3(
        pt[0] - wrist[0],
        pt[1] - wrist[1],
        pt[2] - wrist[2],
      ));
    }
    final double span =
        tipOffsetValues.isEmpty ? 0.0 : tipOffsetValues.reduce(math.max);
    final double scale = math.max(math.max(shoulderDist, span), 1e-4);

    final List<double> selected = <double>[];
    for (final int idx in _handPoints) {
      final List<double> pt = _coords(hand[f], idx);
      selected.addAll(<double>[
        (pt[0] - wrist[0]) / scale,
        (pt[1] - wrist[1]) / scale,
      ]);
    }
    flatXY.add(selected);

    final List<double> tipDistScaled =
        tipOffsetValues.map((v) => v / scale).toList();
    tipDists.add(tipDistScaled);

    final List<double> thumbTip = _coords(hand[f], _thumbTip);
    final List<double> thumbCmc = _coords(hand[f], _thumbCmc);
    final double thumbLen = math.max(
      _norm3(
        thumbTip[0] - thumbCmc[0],
        thumbTip[1] - thumbCmc[1],
        thumbTip[2] - thumbCmc[2],
      ),
      1e-4,
    );
    final List<double> ratioVals = <double>[];
    for (final int idx in _ratioPoints) {
      final List<double> pt = _coords(hand[f], idx);
      ratioVals.add(
        _norm3(pt[0] - thumbTip[0], pt[1] - thumbTip[1], pt[2] - thumbTip[2]) /
            thumbLen,
      );
    }
    ratios.add(ratioVals);
  }

  return _HandFeature(
    flatXY: flatXY,
    tipDists: tipDists,
    ratios: ratios,
  );
}

List<double> _shoulderFeatures(
  List<double> pose,
  List<double> poseVis,
  List<double> leftHand,
  List<double> rightHand,
) {
  final List<double> leftSh =
      _coords(pose, _poseLeftShoulder, poseLandmark: true);
  final List<double> rightSh =
      _coords(pose, _poseRightShoulder, poseLandmark: true);
  final bool validLeft = poseVis[_poseLeftShoulder] > 0.1;
  final bool validRight = poseVis[_poseRightShoulder] > 0.1;
  if (!(validLeft && validRight)) {
    return List<double>.filled(4, 0.0);
  }
  final List<double> center = <double>[
    (leftSh[0] + rightSh[0]) / 2.0,
    (leftSh[1] + rightSh[1]) / 2.0,
    (leftSh[2] + rightSh[2]) / 2.0,
  ];
  final double scale = math.max(
    _norm3(
      leftSh[0] - rightSh[0],
      leftSh[1] - rightSh[1],
      leftSh[2] - rightSh[2],
    ),
    1e-4,
  );
  return <double>[
    (leftSh[0] - center[0]) / scale,
    (leftSh[1] - center[1]) / scale,
    (rightSh[0] - center[0]) / scale,
    (rightSh[1] - center[1]) / scale,
  ];
}

List<double> _confidenceFeatures(
  List<double> leftVis,
  List<double> rightVis,
) {
  final double leftMean =
      leftVis.isEmpty ? 0.0 : leftVis.reduce((a, b) => a + b) / leftVis.length;
  final double rightMean = rightVis.isEmpty
      ? 0.0
      : rightVis.reduce((a, b) => a + b) / rightVis.length;
  return <double>[leftMean, rightMean];
}

List<double> _temporalStats(
  List<List<double>> series, {
  required double threshold,
}) {
  if (series.isEmpty) return <double>[];
  final int cols = series.first.length;
  final int rows = series.length;

  final List<double> means = List<double>.filled(cols, 0.0);
  final List<double> stds = List<double>.filled(cols, 0.0);
  final List<double> maxDelta = List<double>.filled(cols, 0.0);
  final List<double> active = List<double>.filled(cols, 0.0);

  for (int c = 0; c < cols; c++) {
    double sum = 0.0;
    for (int r = 0; r < rows; r++) {
      sum += series[r][c];
    }
    final double mean = sum / rows;
    means[c] = mean;

    double variance = 0.0;
    for (int r = 0; r < rows; r++) {
      final double diff = series[r][c] - mean;
      variance += diff * diff;
    }
    stds[c] = math.sqrt(variance / rows);

    double maxAbs = 0.0;
    for (int r = 1; r < rows; r++) {
      final double delta = (series[r][c] - series[r - 1][c]).abs();
      if (delta > maxAbs) maxAbs = delta;
    }
    maxDelta[c] = maxAbs;

    int activeCount = 0;
    for (int r = 0; r < rows; r++) {
      if (series[r][c] > threshold) activeCount++;
    }
    active[c] = rows == 0 ? 0.0 : activeCount / rows;
  }

  return <double>[...means, ...stds, ...maxDelta, ...active];
}

List<double> _coords(List<double> flat, int index,
    {bool poseLandmark = false}) {
  final int base = index * 4;
  final double x = flat[base];
  final double y = flat[base + 1];
  final double z = flat[base + 2];
  return <double>[x, y, z];
}

List<List<double>> _concatenateSeries(
  List<List<double>> left,
  List<List<double>> right,
) {
  final List<List<double>> combined = <List<double>>[];
  for (int i = 0; i < math.min(left.length, right.length); i++) {
    combined.add(<double>[...left[i], ...right[i]]);
  }
  return combined;
}

double _norm3(double x, double y, double z) => math.sqrt(x * x + y * y + z * z);
