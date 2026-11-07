import 'dart:math';

/// A line shown in the "all done" sheet.
class CelebrationQuote {
  const CelebrationQuote(this.text, this.author);

  final String text;

  /// Who said it. Lines written for the app are credited to Ticky.
  final String author;
}

/// The static collection the "all done" sheet draws from. Add more lines here.
const celebrationQuotes = <CelebrationQuote>[
  CelebrationQuote('Well done is better than well said.', 'Benjamin Franklin'),
  CelebrationQuote(
    'Small deeds done are better than great deeds planned.',
    'Peter Marshall',
  ),
  CelebrationQuote(
    'The journey of a thousand miles begins with a single step.',
    'Lao Tzu',
  ),
  CelebrationQuote(
    'We are what we repeatedly do. Excellence, then, is not an act, but a habit.',
    'Will Durant',
  ),
  CelebrationQuote(
    'It always seems impossible until it is done.',
    'Nelson Mandela',
  ),
  CelebrationQuote('Tick, tock. Look at you go!', 'Ticky'),
  CelebrationQuote('Every tick you checked was a promise you kept.', 'Ticky'),
  CelebrationQuote('Tiny tasks, big days. You just proved it.', 'Ticky'),
  CelebrationQuote('Today, you showed up. That is the whole trick.', 'Ticky'),
  CelebrationQuote(
    'A tidy list and a calm mind. Enjoy the rest of your day.',
    'Ticky',
  ),
  CelebrationQuote(
    'One more day on the board. Keep the streak glowing.',
    'Ticky',
  ),
  CelebrationQuote('You did the thing. All of the things!', 'Ticky'),
];

/// A random line. Pass [random] to make it repeatable in tests.
CelebrationQuote randomCelebrationQuote([Random? random]) {
  final rng = random ?? Random();
  return celebrationQuotes[rng.nextInt(celebrationQuotes.length)];
}
