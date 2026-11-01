/// Task urgency. Stored as text using [Enum.name].
enum Priority { low, medium, high }

/// State of one task on one calendar day. Stored as text using [Enum.name].
enum TaskStatus { pending, completed, skipped, missed }

/// Kind of coin ledger entry. Stored as text using [Enum.name].
enum RewardType { taskComplete, perfectDay, spend }
