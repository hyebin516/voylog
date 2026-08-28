/// `available: false` means fewer than 2 videos have commented on this
/// place yet -- there's nothing to cross-reference, which is distinct from
/// "the request failed".
class PlaceSummaryModel {
  final bool available;
  final String? pros;
  final String? cons;
  final int sourceCount;

  const PlaceSummaryModel({required this.available, required this.pros, required this.cons, required this.sourceCount});

  factory PlaceSummaryModel.fromJson(Map<String, dynamic> json) {
    return PlaceSummaryModel(
      available: json['available'] as bool,
      pros: json['pros'] as String?,
      cons: json['cons'] as String?,
      sourceCount: json['sourceCount'] as int,
    );
  }
}
