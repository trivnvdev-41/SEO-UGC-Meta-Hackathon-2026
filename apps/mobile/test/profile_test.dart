import 'package:flutter_test/flutter_test.dart';
import 'package:seo_ugc/profile.dart';

void main() {
  test('ProfileStore simpan dan reset', () {
    ProfileStore.name = 'Dimas';
    ProfileStore.about = 'Halo';
    ProfileStore.topics = ['teknologi'];
    ProfileStore.showBadge = false;
    ProfileStore.reset();
    expect(ProfileStore.name, isEmpty);
    expect(ProfileStore.about, isEmpty);
    expect(ProfileStore.topics, isEmpty);
    expect(ProfileStore.showBadge, isTrue);
  });
}
