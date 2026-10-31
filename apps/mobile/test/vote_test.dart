import 'package:flutter_test/flutter_test.dart';
import 'package:seo_ugc/vote.dart';

void main() {
  test('toggle up/down saling eksklusif', () {
    VoteStore.upvoted.clear();
    VoteStore.downvoted.clear();
    VoteStore.toggleUp('a');
    expect(VoteStore.upvoted.contains('a'), isTrue);
    VoteStore.toggleDown('a');
    expect(VoteStore.upvoted.contains('a'), isFalse);
    expect(VoteStore.downvoted.contains('a'), isTrue);
    VoteStore.toggleDown('a');
    expect(VoteStore.downvoted.contains('a'), isFalse);
  });

  test('format counter kompak vs eksak', () {
    expect(compactVotes(856), '856');
    expect(compactVotes(2400), '2.4k');
    expect(compactVotes(1100), '1.1k');
    expect(exactVotes(2401), '2,401');
    expect(exactVotes(857), '857');
  });

  test('baseVotes stabil', () {
    expect(baseVotes('x'), baseVotes('x'));
  });
}
