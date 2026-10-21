import 'dart:ui' show Color;

/// One customer review on the Review Details tab.
class Review {
  const Review({
    required this.name,
    required this.stars,
    required this.title,
    required this.text,
    required this.when,
    required this.avatar,
    this.photo,
    this.verified = true,
    this.helpful = 0,
  });

  final String name;
  final int stars;
  final String title;
  final String text;
  final String when;
  final Color avatar;

  /// Gradient colors of an attached customer photo, if any.
  final List<Color>? photo;
  final bool verified;
  final int helpful;
}

/// The header's "4.7 · 2,184 reviews", matching the native page.
const int kReviewCount = 2184;
const Map<int, int> kStarCounts = {5: 1720, 4: 312, 3: 98, 2: 31, 1: 23};
const double kAverageRating = 4.7;

/// The first six are the ones the native Overview tab shows, in the same
/// order and words, so switching tabs never contradicts the page.
const List<Review> kReviews = [
  Review(
    name: 'Maya R.',
    stars: 5,
    title: 'Silence on the 7:40',
    text: 'The noise cancelling on a train is unreal.',
    when: '2 days ago',
    avatar: Color(0xFF5856D6),
    photo: [Color(0xFF5856D6), Color(0xFFAF52DE), Color(0xFFFF2D55)],
    helpful: 214,
  ),
  Review(
    name: 'Tomás',
    stars: 5,
    title: 'Forgot I was wearing them',
    text: 'Comfortable for a full workday.',
    when: '4 days ago',
    avatar: Color(0xFF34C759),
    helpful: 96,
  ),
  Review(
    name: 'Priya K.',
    stars: 4,
    title: 'Great sound, chunky case',
    text: 'Great sound, the case is a little bulky.',
    when: '1 week ago',
    avatar: Color(0xFFFF9500),
    photo: [Color(0xFFFF9500), Color(0xFFFF2D55)],
    helpful: 77,
  ),
  Review(
    name: 'Jun',
    stars: 5,
    title: 'A week on one charge',
    text: 'Battery lasted a whole week of commuting.',
    when: '1 week ago',
    avatar: Color(0xFF007AFF),
    helpful: 58,
  ),
  Review(
    name: 'Alex',
    stars: 4,
    title: 'Clear calls outside',
    text: 'Calls are clear, even outdoors.',
    when: '2 weeks ago',
    avatar: Color(0xFF8E8E93),
    helpful: 31,
  ),
  Review(
    name: 'Sam W.',
    stars: 5,
    title: 'Movies feel huge',
    text: 'Spatial audio makes movies feel huge.',
    when: '2 weeks ago',
    avatar: Color(0xFFFF2D55),
    photo: [Color(0xFF32ADE6), Color(0xFF5856D6)],
    helpful: 44,
  ),
  Review(
    name: 'Lena',
    stars: 5,
    title: 'Sky blue is gorgeous',
    text:
        'The Sky colour looks even better in person. The aluminium feels '
        'premium and the band does not creak.',
    when: '3 weeks ago',
    avatar: Color(0xFF32ADE6),
    photo: [Color(0xFF64D2FF), Color(0xFF0A84FF), Color(0xFF5E5CE6)],
    helpful: 39,
  ),
  Review(
    name: 'Omar H.',
    stars: 4,
    title: 'Switches between my devices',
    text:
        'Moves from laptop to phone on its own. Took a firmware update to '
        'get there, but it works now.',
    when: '3 weeks ago',
    avatar: Color(0xFFAF52DE),
    helpful: 22,
  ),
  Review(
    name: 'Chloé',
    stars: 5,
    title: 'Best flight of my life',
    text: 'Twelve hours to Tokyo and I heard the engines exactly zero times.',
    when: '1 month ago',
    avatar: Color(0xFFFF3B30),
    photo: [Color(0xFFFFCC00), Color(0xFFFF9500), Color(0xFFFF3B30)],
    helpful: 187,
  ),
  Review(
    name: 'Ben',
    stars: 3,
    title: 'Good, not magic',
    text:
        'Sound is very good. The touch controls take a while to learn and '
        'I paused my music by accident a few times.',
    when: '1 month ago',
    avatar: Color(0xFF8E8E93),
    verified: false,
    helpful: 12,
  ),
  Review(
    name: 'Aiko',
    stars: 5,
    title: 'Light enough to forget',
    text: 'At 254 g I wear them all day in the studio. The cushions stay cool.',
    when: '1 month ago',
    avatar: Color(0xFF30B0C7),
    photo: [Color(0xFF30D158), Color(0xFF30B0C7)],
    helpful: 41,
  ),
  Review(
    name: 'Daniel P.',
    stars: 4,
    title: 'Wind is finally quiet',
    text: 'Cycling calls used to be useless. Six mics make a real difference.',
    when: '2 months ago',
    avatar: Color(0xFF34C759),
    helpful: 18,
  ),
  Review(
    name: 'Grace',
    stars: 5,
    title: 'Folds flat in my bag',
    text: 'They fold flat and the case slides into a laptop sleeve.',
    when: '2 months ago',
    avatar: Color(0xFFFF2D55),
    photo: [Color(0xFFFF375F), Color(0xFFBF5AF2)],
    helpful: 26,
  ),
  Review(
    name: 'Marco',
    stars: 2,
    title: 'Clamp force too tight',
    text: 'Great noise cancelling, but too tight on my head after an hour.',
    when: '3 months ago',
    avatar: Color(0xFFFF9500),
    helpful: 9,
  ),
  Review(
    name: 'Nina S.',
    stars: 5,
    title: 'Worth it',
    text: 'Bought them on sale with the holo badge code. Zero regrets.',
    when: '3 months ago',
    avatar: Color(0xFF5E5CE6),
    photo: [Color(0xFF0C0A1C), Color(0xFF5E5CE6), Color(0xFFBF5AF2)],
    helpful: 64,
  ),
];
