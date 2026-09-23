class LessonContent {
  final String id;
  final String prompt;
  final String answer;

  const LessonContent({
    required this.id,
    required this.prompt,
    required this.answer,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'prompt': prompt,
        'answer': answer,
      };

  factory LessonContent.fromMap(Map<String, Object?> map) => LessonContent(
        id: map['id']! as String,
        prompt: map['prompt']! as String,
        answer: map['answer']! as String,
      );
}
