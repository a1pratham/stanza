/// The interest taxonomy from `topic_groups`/`topics` -- public reference
/// data, not user-owned, which is why this is a separate file from
/// profile.dart rather than bundled with it.
class TopicGroup {
  final String groupId;
  final String name;
  final String? description;
  final List<Topic> topics;

  const TopicGroup({
    required this.groupId,
    required this.name,
    this.description,
    required this.topics,
  });
}

class Topic {
  final String topicId;
  final String groupId;
  final String name;

  const Topic({
    required this.topicId,
    required this.groupId,
    required this.name,
  });
}
