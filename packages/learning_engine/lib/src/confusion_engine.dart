class ConfusionAttempt {
  final String expected;
  final String response;

  const ConfusionAttempt({required this.expected, required this.response});
}

class ConfusionEdge {
  final String key;
  final String expected;
  final String response;
  final int exposureCount;
  final int errorCount;
  final double? _errorRateOverride;

  const ConfusionEdge({String? key, required this.expected, required this.response, required this.exposureCount, required this.errorCount, double? errorRateOverride}) : key = key ?? '$expected->$response', _errorRateOverride = errorRateOverride;

  double get errorRate => _errorRateOverride ?? (exposureCount == 0 ? 0 : errorCount / exposureCount);
}

class ConfusionTarget extends ConfusionEdge {
  const ConfusionTarget({required super.expected, required super.response, required double errorRate, required super.exposureCount, required super.errorCount}) : super(errorRateOverride: errorRate);
}

abstract interface class ConfusionEngine {
  ConfusionEdge record(ConfusionAttempt attempt);
  List<ConfusionTarget> targets();
}

class InMemoryConfusionEngine implements ConfusionEngine {
  final int minimumExposure;
  final Map<String, ConfusionEdge> _edges = {};

  InMemoryConfusionEngine({this.minimumExposure = 2});

  @override
  ConfusionEdge record(ConfusionAttempt attempt) {
    final pair = _ordered(attempt.expected.trim(), attempt.response.trim());
    final old = _edges[pair.key];
    final edge = ConfusionEdge(
      key: pair.key,
      expected: pair.expected,
      response: pair.response,
      exposureCount: (old?.exposureCount ?? 0) + 1,
      errorCount: (old?.errorCount ?? 0) + 1,
    );
    _edges[pair.key] = edge;
    return edge;
  }

  void exposeCorrect(String expected, String response) {
    final pair = _ordered(expected.trim(), response.trim());
    final old = _edges[pair.key];
    _edges[pair.key] = ConfusionEdge(
      key: pair.key, expected: pair.expected, response: pair.response,
      exposureCount: (old?.exposureCount ?? 0) + 1,
      errorCount: old?.errorCount ?? 0,
    );
  }

  @override
  List<ConfusionTarget> targets() => _edges.values
      .where((edge) => edge.exposureCount >= minimumExposure && edge.errorCount > 0)
      .map((edge) => ConfusionTarget(expected: edge.expected, response: edge.response, errorRate: edge.errorRate, exposureCount: edge.exposureCount, errorCount: edge.errorCount))
      .toList()
    ..sort((a, b) => b.errorRate.compareTo(a.errorRate) != 0
        ? b.errorRate.compareTo(a.errorRate)
        : a.key.compareTo(b.key));
}

({String key, String expected, String response}) _ordered(String a, String b) {
  return (key: '$a->$b', expected: a, response: b);
}
