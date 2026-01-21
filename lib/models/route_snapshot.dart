class RouteCoordinate {
  final double latitude;
  final double longitude;

  const RouteCoordinate({
    required this.latitude,
    required this.longitude,
  });
}

class RouteSnapshot {
  final String walkId;
  final List<RouteCoordinate> coordinates;

  const RouteSnapshot({
    required this.walkId,
    required this.coordinates,
  });
}
