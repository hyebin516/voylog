class BookmarkFolderModel {
  final String folderId;
  final String name;
  final int bookmarkCount;
  final DateTime createdAt;

  const BookmarkFolderModel({
    required this.folderId,
    required this.name,
    required this.bookmarkCount,
    required this.createdAt,
  });

  factory BookmarkFolderModel.fromJson(Map<String, dynamic> json) {
    return BookmarkFolderModel(
      folderId: json['folderId'] as String,
      name: json['name'] as String,
      bookmarkCount: json['bookmarkCount'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
