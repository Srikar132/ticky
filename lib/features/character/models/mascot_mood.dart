/// Ticky's states (AGENTS.md section 11).
enum MascotMood {
  idle,
  happy,
  excited,
  thinking,
  sleepy,
  surprised,
  celebrating,
  reminding,
  overdue,
}

/// Picks Ticky's mood from plain values, so the mascot knows nothing about
/// checklists or notifications. Computed at runtime, never stored.
///
/// Order matters: the first matching rule wins.
MascotMood mascotMoodFor({
  required bool hasRoutines,
  required bool hasTasksToday,
  required int completed,
  required double progress,
  required bool allDone,
  required bool anyOverdue,
  required bool dueSoon,
  required int hour,
}) {
  final lateNight = hour >= 22 || hour < 5;
  if (!hasRoutines) return MascotMood.thinking;
  if (!hasTasksToday) return lateNight ? MascotMood.sleepy : MascotMood.idle;
  if (allDone) return MascotMood.celebrating;
  if (anyOverdue) return MascotMood.overdue;
  if (dueSoon) return MascotMood.reminding;
  if (lateNight) return MascotMood.sleepy;
  if (progress >= 0.5) return MascotMood.excited;
  if (completed > 0) return MascotMood.happy;
  return MascotMood.idle;
}

/// Short lines Ticky says. Tapping Ticky cycles through them.
const mascotMessages = <MascotMood, List<String>>{
  MascotMood.idle: [
    "Let's tick things off today!",
    'One small task is a great start.',
    "I'm ready when you are!",
  ],
  MascotMood.happy: [
    'Nice start! Keep it going.',
    "That's one down. You're on a roll!",
    'Look at you go!',
  ],
  MascotMood.excited: [
    "You're more than halfway there!",
    "Wow, you're flying today!",
    'Almost there. Keep going!',
  ],
  MascotMood.thinking: [
    'Hmm… what shall we do each day?',
    'Add your first routine and I will remind you.',
  ],
  MascotMood.sleepy: [
    'Zzz… time to rest soon.',
    "It's late. Tomorrow is a fresh start.",
  ],
  MascotMood.surprised: ['Oh! You tapped me!', 'Hehe, that tickles!'],
  MascotMood.celebrating: [
    'All done! What a day!',
    'Perfect! I am so proud of you!',
  ],
  MascotMood.reminding: [
    'Psst… something is coming up soon.',
    'Almost time for your next task!',
  ],
  MascotMood.overdue: [
    "Don't worry, you can still do it!",
    'A task is waiting. Want to tick it off?',
  ],
};

/// The [index]th line for [mood], wrapping around.
String mascotMessage(MascotMood mood, int index) {
  final lines = mascotMessages[mood]!;
  return lines[index % lines.length];
}
