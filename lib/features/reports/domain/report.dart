/// Why a reader is reporting a confession.
enum ReportReason {
  harassment('Harassment or bullying'),
  identifiesPerson('Names or identifies a real person, school or company'),
  personalInfo('Shares private info (address, phone, etc.)'),
  threat('Threats, violence or self-harm'),
  hate('Hate speech'),
  sexualContent('Sexual content involving minors or non-consent'),
  spam('Spam or misleading'),
  other('Something else');

  const ReportReason(this.label);
  final String label;

  static ReportReason parse(Object? raw) => ReportReason.values.firstWhere(
    (r) => r.name == raw,
    orElse: () => ReportReason.other,
  );
}
