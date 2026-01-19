import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 앱 모듈 정의
enum AppModule {
  memory('추억', 'memory'),
  budget('가계부', 'budget'),
  people('사람들', 'people');

  final String label;
  final String key;
  const AppModule(this.label, this.key);

  static AppModule? fromKey(String key) {
    try {
      return AppModule.values.firstWhere((m) => m.key == key);
    } catch (e) {
      return null;
    }
  }
}

/// 모듈 정보
class ModuleInfo {
  final AppModule module;
  final bool isEnabled;
  final int order;

  const ModuleInfo({
    required this.module,
    required this.isEnabled,
    required this.order,
  });

  ModuleInfo copyWith({
    AppModule? module,
    bool? isEnabled,
    int? order,
  }) {
    return ModuleInfo(
      module: module ?? this.module,
      isEnabled: isEnabled ?? this.isEnabled,
      order: order ?? this.order,
    );
  }
}

/// 활성화된 모듈 관리 Notifier
class EnabledModulesNotifier extends StateNotifier<Map<AppModule, ModuleInfo>> {
  EnabledModulesNotifier() : super(_defaultModules);

  /// 기본 모듈 설정 (모두 활성화)
  static final Map<AppModule, ModuleInfo> _defaultModules = {
    AppModule.memory: const ModuleInfo(
      module: AppModule.memory,
      isEnabled: true,
      order: 0,
    ),
    AppModule.budget: const ModuleInfo(
      module: AppModule.budget,
      isEnabled: true,
      order: 1,
    ),
    AppModule.people: const ModuleInfo(
      module: AppModule.people,
      isEnabled: true,
      order: 2,
    ),
  };

  /// 모듈 활성화/비활성화 토글
  void toggleModule(AppModule module) {
    final currentInfo = state[module];
    if (currentInfo == null) return;

    state = {
      ...state,
      module: currentInfo.copyWith(isEnabled: !currentInfo.isEnabled),
    };
  }

  /// 모듈 활성화 설정
  void setModuleEnabled(AppModule module, bool enabled) {
    final currentInfo = state[module];
    if (currentInfo == null) return;

    state = {
      ...state,
      module: currentInfo.copyWith(isEnabled: enabled),
    };
  }

  /// 모듈 순서 변경
  void reorderModule(AppModule module, int newOrder) {
    final currentInfo = state[module];
    if (currentInfo == null) return;

    final modules = state.entries.toList();
    final oldOrder = currentInfo.order;

    // 순서 재조정
    final newState = <AppModule, ModuleInfo>{};
    for (final entry in modules) {
      var order = entry.value.order;
      if (entry.key == module) {
        order = newOrder;
      } else if (oldOrder < newOrder) {
        // 위에서 아래로 이동
        if (order > oldOrder && order <= newOrder) {
          order--;
        }
      } else {
        // 아래에서 위로 이동
        if (order >= newOrder && order < oldOrder) {
          order++;
        }
      }
      newState[entry.key] = entry.value.copyWith(order: order);
    }

    state = newState;
  }

  /// 모든 모듈 초기화 (기본값으로)
  void resetToDefault() {
    state = Map.from(_defaultModules);
  }
}

/// 모듈 설정 Provider
final enabledModulesProvider =
    StateNotifierProvider<EnabledModulesNotifier, Map<AppModule, ModuleInfo>>(
  (ref) => EnabledModulesNotifier(),
);

/// 활성화된 모듈 목록 (순서대로)
final activeModulesProvider = Provider<List<AppModule>>((ref) {
  final modules = ref.watch(enabledModulesProvider);
  
  final activeModules = modules.entries
      .where((e) => e.value.isEnabled)
      .toList()
    ..sort((a, b) => a.value.order.compareTo(b.value.order));
  
  return activeModules.map((e) => e.key).toList();
});

/// 특정 모듈 활성화 여부
final isModuleEnabledProvider = Provider.family<bool, AppModule>((ref, module) {
  final modules = ref.watch(enabledModulesProvider);
  return modules[module]?.isEnabled ?? false;
});
