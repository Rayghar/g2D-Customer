class Feedback {
  final String id;
  final String orderId;
  final int rating;
  final String comment;

  Feedback({
    required this.id,
    required this.orderId,
    required this.rating,
    required this.comment,
  });

  factory Feedback.fromJson(Map<String, dynamic> json) {
    return Feedback(
      id: json['id'] ?? '',
      orderId: json['orderId'] ?? '',
      rating: json['rating'] ?? 0,
      comment: json['comment'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'orderId': orderId,
      'rating': rating,
      'comment': comment,
    };
  }
}
