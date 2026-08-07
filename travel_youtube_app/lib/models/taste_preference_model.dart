class TastePreferenceModel {
  final List<String> tags;

  const TastePreferenceModel({required this.tags});

  factory TastePreferenceModel.fromJson(Map<String, dynamic> json) {
    return TastePreferenceModel(tags: (json['tags'] as List<dynamic>).map((e) => e as String).toList());
  }
}
