class ChatSession {
  final String? budget;
  final String? travelType;

  ChatSession({this.budget, this.travelType});

  Map<String, dynamic> toJson() {
    return {"budget": budget, "travel_type": travelType};
  }

  ChatSession copyWith({String? budget, String? travelType}) {
    return ChatSession(
      budget: budget ?? this.budget,
      travelType: travelType ?? this.travelType,
    );
  }
}

class ChatbotResponse {
  final String type;
  final String? message;
  final String? budget;
  final String? travelType;

  ChatbotResponse({
    required this.type,
    this.message,
    this.budget,
    this.travelType,
  });

  factory ChatbotResponse.fromJson(Map<String, dynamic> json) {
    return ChatbotResponse(
      type: json['type'],
      message: json['message'],
      budget: json['budget'],
      travelType: json['travel_type'],
    );
  }
}
