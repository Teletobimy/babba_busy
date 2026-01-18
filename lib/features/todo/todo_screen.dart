import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/providers/todo_provider.dart';

/// 할일 상세 화면 (개별 할일 편집)
class TodoScreen extends ConsumerStatefulWidget {
  final String? todoId;

  const TodoScreen({super.key, this.todoId});

  @override
  ConsumerState<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends ConsumerState<TodoScreen> {
  @override
  Widget build(BuildContext context) {
    final todos = ref.watch(todosProvider).value ?? [];
    final todo = widget.todoId != null
        ? todos.firstWhere(
            (t) => t.id == widget.todoId,
            orElse: () => throw Exception('Todo not found'),
          )
        : null;

    if (todo == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Iconsax.arrow_left),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: const Center(
          child: Text('할일을 찾을 수 없습니다'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Iconsax.arrow_left),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('할일 상세'),
        actions: [
          IconButton(
            icon: const Icon(Iconsax.trash),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('할일 삭제'),
                  content: const Text('이 할일을 삭제하시겠습니까?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('취소'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('삭제'),
                    ),
                  ],
                ),
              );
              if (confirmed == true && mounted) {
                ref.read(todoServiceProvider).deleteTodo(todo.id);
                Navigator.of(context).pop();
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              todo.title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (todo.note != null && todo.note!.isNotEmpty) ...[
              const SizedBox(height: AppTheme.spacingM),
              Text(
                todo.note!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
