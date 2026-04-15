class PaginatedResponse<T> {
  const PaginatedResponse({
    required this.data,
    required this.total,
    required this.page,
    required this.perPage,
  });

  final List<T> data;
  final int total;
  final int page;
  final int perPage;

  int get totalPages => (total / perPage).ceil();
  bool get hasNext => page < totalPages;
  bool get hasPrevious => page > 1;

  Map<String, dynamic> toJson(Map<String, dynamic> Function(T) toJsonT) => {
        'data': data.map(toJsonT).toList(),
        'total': total,
        'page': page,
        'per_page': perPage,
        'total_pages': totalPages,
      };

  factory PaginatedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJsonT,
  ) =>
      PaginatedResponse(
        data: (json['data'] as List)
            .map((e) => fromJsonT(e as Map<String, dynamic>))
            .toList(),
        total: json['total'] as int,
        page: json['page'] as int,
        perPage: json['per_page'] as int,
      );
}
