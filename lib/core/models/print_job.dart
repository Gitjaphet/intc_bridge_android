class PrintJob {
  final String content;
  final int copies;
  final DateTime receivedAt;

  PrintJob({
    required this.content,
    this.copies = 1,
    DateTime? receivedAt,
  }) : receivedAt = receivedAt ?? DateTime.now();

  factory PrintJob.fromJson(Map<String, dynamic> json) => PrintJob(
    content: json['content'] ?? '',
    copies: json['copies'] ?? 1,
  );
}
