// File: lib/models/admin/faq_item_model.dart

// Option 2.A: Throw error if ID is missing from JSON (Recommended if ID is essential)
// import 'package:flutter/foundation.dart'; // For kDebugMode if you want to print

class FaqItemModel {
  final String id;
  String question;
  String answer;
  int displayOrder;
  bool isActive;
  String? category;

  FaqItemModel({
    required this.id,
    required this.question,
    required this.answer,
    this.displayOrder = 0,
    this.isActive = true,
    this.category,
  });

  factory FaqItemModel.fromJson(Map<String, dynamic> json) {
    final idFromJson = json['id'] as String?;
    if (idFromJson == null || idFromJson.isEmpty) {
      // Option 2.A.1: Throw an error if ID is critical and must come from backend
      throw FormatException("FAQ ID is missing or empty in JSON data: $json");

      // Option 2.A.2: Or assign a non-UI dependent placeholder / log an error for debugging
      // print("Warning: FAQ ID missing in JSON, using placeholder. JSON: $json");
      // idFromJson = 'temp_id_${DateTime.now().millisecondsSinceEpoch}'; // Not ideal for persistent data
    }
    return FaqItemModel(
      id: idFromJson, // Now ensured to be non-null or you've handled it
      question: json['question'] as String? ?? '',
      answer: json['answer'] as String? ?? '',
      displayOrder: (json['displayOrder'] as num?)?.toInt() ?? 0,
      isActive: (json['isActive'] as bool?) ?? true,
      category: json['category'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question': question,
      'answer': answer,
      'displayOrder': displayOrder,
      'isActive': isActive,
      if (category != null) 'category': category,
    };
  }
}
