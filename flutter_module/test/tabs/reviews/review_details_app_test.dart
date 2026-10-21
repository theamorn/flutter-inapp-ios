import 'package:flutter_module/tabs/reviews/review_details_app.dart';
import 'package:flutter_module/tabs/reviews/reviews_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

void main() {
  testWidgets('shows the rating summary, filters, and button on glass', (
    tester,
  ) async {
    await tester.pumpWidget(const ReviewDetailsApp());
    await tester.pump();

    // The cards' glass and the floating controls' glass.
    expect(find.byType(LiquidGlassLayer), findsNWidgets(2));
    expect(find.text('4.7'), findsOneWidget);
    expect(find.text('2,184 ratings'), findsOneWidget);
    for (final filter in ReviewFilter.values) {
      expect(find.text(filter.label), findsOneWidget);
    }
    expect(find.text('Write a review'), findsOneWidget);
    expect(find.text(kReviews.first.title), findsOneWidget);
  });

  testWidgets('a filter chip filters the list', (tester) async {
    await tester.pumpWidget(const ReviewDetailsApp());
    await tester.pump();

    await tester.tap(find.text(ReviewFilter.four.label));
    await tester.pumpAndSettle();

    final firstFour = kReviews.firstWhere((review) => review.stars == 4);
    expect(find.text(firstFour.title), findsOneWidget);
    expect(find.text(kReviews.first.title), findsNothing);
  });

  testWidgets('All merges the star chips, and splits them again', (
    tester,
  ) async {
    await tester.pumpWidget(const ReviewDetailsApp());
    await tester.pump();
    final firstFour = kReviews.firstWhere((review) => review.stars == 4);

    // Merged: the star chips sit inside "All". A tap where 4 ★ was lands
    // on the merged pill, which splits the group instead of filtering.
    await tester.tap(find.text(ReviewFilter.all.label));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ReviewFilter.four.label), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text(kReviews.first.title), findsOneWidget);

    // Split again: 4 ★ filters.
    await tester.tap(find.text(ReviewFilter.four.label));
    await tester.pumpAndSettle();
    expect(find.text(firstFour.title), findsOneWidget);
    expect(find.text(kReviews.first.title), findsNothing);
  });

  testWidgets('Most helpful sorts by helpful votes', (tester) async {
    await tester.pumpWidget(const ReviewDetailsApp());
    await tester.pump();

    final sorted = ReviewFilter.helpful.apply(kReviews);
    expect(sorted.length, kReviews.length);
    for (var i = 1; i < sorted.length; i++) {
      expect(sorted[i - 1].helpful, greaterThanOrEqualTo(sorted[i].helpful));
    }
    expect(ReviewFilter.low.apply(kReviews).every((r) => r.stars <= 2), isTrue);
  });

  test('the summary agrees with the native page', () {
    final total = kStarCounts.values.reduce((a, b) => a + b);
    final weighted = kStarCounts.entries
        .map((entry) => entry.key * entry.value)
        .reduce((a, b) => a + b);

    expect(total, kReviewCount);
    expect((weighted / total * 10).round() / 10, kAverageRating);
  });
}
