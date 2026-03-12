import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 홈 화면 섹션 ID
enum HomeSection {
  aiSummary('오늘의 현황'),
  couple('커플 카드'),
  memberFilter('구성원 필터'),
  todos('할 일'),
  activityFeed('최근 활동'),
  upcomingEvents('다가오는 일정'),
  dday('D-day');

  final String label;
  const HomeSection(this.label);
}

/// 홈 화면 레이아웃 설정
class HomeLayoutConfig {
  final List<HomeSection> order;
  final Set<HomeSection> hidden;

  const HomeLayoutConfig({
    required this.order,
    required this.hidden,
  });

  factory HomeLayoutConfig.defaults() => HomeLayoutConfig(
    order: HomeSection.values.toList(),
    hidden: const {},
  );

  bool isVisible(HomeSection section) => !hidden.contains(section);

  HomeLayoutConfig copyWith({
    List<HomeSection>? order,
    Set<HomeSection>? hidden,
  }) => HomeLayoutConfig(
    order: order ?? this.order,
    hidden: hidden ?? this.hidden,
  );
}

const _storageKey = 'home_layout_config';

class HomeLayoutNotifier extends StateNotifier<HomeLayoutConfig> {
  HomeLayoutNotifier() : super(HomeLayoutConfig.defaults()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_storageKey);
    if (json != null) {
      final data = jsonDecode(json) as Map<String, dynamic>;
      final orderNames = (data['order'] as List?)?.cast<String>() ?? [];
      final hiddenNames = (data['hidden'] as List?)?.cast<String>() ?? [];

      final order = orderNames
          .map((n) {
            try { return HomeSection.values.byName(n); } catch (_) { return null; }
          })
          .whereType<HomeSection>()
          .toList();

      // 누락된 섹션 추가
      for (final section in HomeSection.values) {
        if (!order.contains(section)) order.add(section);
      }

      final hidden = hiddenNames
          .map((n) {
            try { return HomeSection.values.byName(n); } catch (_) { return null; }
          })
          .whereType<HomeSection>()
          .toSet();

      state = HomeLayoutConfig(order: order, hidden: hidden);
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode({
      'order': state.order.map((s) => s.name).toList(),
      'hidden': state.hidden.map((s) => s.name).toList(),
    }));
  }

  void toggleSection(HomeSection section) {
    final hidden = Set<HomeSection>.from(state.hidden);
    if (hidden.contains(section)) {
      hidden.remove(section);
    } else {
      hidden.add(section);
    }
    state = state.copyWith(hidden: hidden);
    _save();
  }

  void reorder(int oldIndex, int newIndex) {
    final order = List<HomeSection>.from(state.order);
    if (newIndex > oldIndex) newIndex--;
    final item = order.removeAt(oldIndex);
    order.insert(newIndex, item);
    state = state.copyWith(order: order);
    _save();
  }

  void reset() {
    state = HomeLayoutConfig.defaults();
    _save();
  }
}

final homeLayoutProvider =
    StateNotifierProvider<HomeLayoutNotifier, HomeLayoutConfig>(
  (ref) => HomeLayoutNotifier(),
);
