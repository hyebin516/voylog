/// Where an FR-17 walking course starts and ends.
///
/// Deliberately not a [HotelModel]: a walking course start is a point the
/// user picks on the map for that one course, with no connection to the
/// trip planner's saved accommodations, and it is never persisted on its
/// own.
class StartPointModel {
  final String name;
  final double latitude;
  final double longitude;

  const StartPointModel({
    required this.name,
    required this.latitude,
    required this.longitude,
  });
}
