import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/providers/group_provider.dart';

class GroupSetupDialog extends ConsumerStatefulWidget {
  final bool isJoinOnly;
  
  const GroupSetupDialog({
    super.key,
    this.isJoinOnly = false,
  });

  @override
  ConsumerState<GroupSetupDialog> createState() => _GroupSetupDialogState();
}

class _GroupSetupDialogState extends ConsumerState<GroupSetupDialog> {
  late String _mode;
  final _formKey = GlobalKey<FormState>();
  
  final _groupNameController = TextEditingController();
  final _memberNameController = TextEditingController();
  final _inviteCodeController = TextEditingController();
  
  int _selectedColorIndex = 0;
  bool _isLoading = false;
  String? _errorMessage;
  String? _newInviteCode;

  @override
  void initState() {
    super.initState();
    _mode = widget.isJoinOnly ? 'join' : 'selection';
    
    // 기본 이름 설정 (현재 사용자 이름이 있으면)
    final user = ref.read(currentUserProvider);
    if (user?.displayName != null) {
      _memberNameController.text = user!.displayName!;
    }
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    _memberNameController.dispose();
    _inviteCodeController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = ref.read(authServiceProvider);
      final color = AppColors.memberColors[_selectedColorIndex];
      final colorHex = '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';

      if (_mode == 'create') {
        final result = await authService.createFamily(
          _groupNameController.text.trim(),
          _memberNameController.text.trim(),
          colorHex,
        );
        if (result == null) {
          throw Exception('그룹 생성에 실패했습니다.');
        }

        // 새로 생성한 그룹을 selectedGroupIdProvider에 직접 설정
        ref.read(selectedGroupIdProvider.notifier).state = result.groupId;

        // SharedPreferences에도 저장
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_selected_group_id', result.groupId);

        setState(() => _newInviteCode = result.inviteCode);
      } else if (_mode == 'join') {
        await authService.joinFamily(
          _inviteCodeController.text.trim(),
          _memberNameController.text.trim(),
          colorHex,
        );
        if (mounted) Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_newInviteCode != null) {
      return _buildSuccessView();
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLarge)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (_mode != 'selection' && !widget.isJoinOnly)
                    IconButton(
                      icon: const Icon(Iconsax.arrow_left_1),
                      onPressed: () => setState(() => _mode = 'selection'),
                    ),
                  Expanded(
                    child: Text(
                      _getTitle(),
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: (widget.isJoinOnly || _mode == 'selection') ? TextAlign.center : TextAlign.start,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Iconsax.close_circle),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingM),
              
              if (_mode == 'selection') _buildSelectionView()
              else _buildFormView(),
            ],
          ),
        ),
      ),
    );
  }

  String _getTitle() {
    switch (_mode) {
      case 'create': return '새 그룹 만들기';
      case 'join': return '그룹 참여하기';
      default: return '그룹 추가';
    }
  }

  Widget _buildSelectionView() {
    return Column(
      children: [
        _SelectionItem(
          icon: Iconsax.add_circle,
          title: '새 그룹 만들기',
          onTap: () => setState(() => _mode = 'create'),
        ),
        const SizedBox(height: AppTheme.spacingM),
        _SelectionItem(
          icon: Iconsax.key,
          title: '초대 코드로 참여',
          onTap: () => setState(() => _mode = 'join'),
        ),
      ],
    );
  }

  Widget _buildFormView() {
    final isCreate = _mode == 'create';
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isCreate)
            TextFormField(
              controller: _groupNameController,
              decoration: const InputDecoration(labelText: '그룹 이름', prefixIcon: Icon(Iconsax.home)),
              validator: (v) => (v == null || v.isEmpty) ? '이름을 입력하세요' : null,
            )
          else
            TextFormField(
              controller: _inviteCodeController,
              decoration: const InputDecoration(labelText: '초대 코드', prefixIcon: Icon(Iconsax.key)),
              textCapitalization: TextCapitalization.characters,
              validator: (v) => (v == null || v.isEmpty) ? '코드를 입력하세요' : null,
            ),
          const SizedBox(height: AppTheme.spacingM),
          TextFormField(
            controller: _memberNameController,
            decoration: const InputDecoration(labelText: '내 이름 (별명)', prefixIcon: Icon(Iconsax.user)),
            validator: (v) => (v == null || v.isEmpty) ? '이름을 입력하세요' : null,
          ),
          const SizedBox(height: AppTheme.spacingL),
          Text('나의 색상', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppTheme.spacingS),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(
              AppColors.memberColors.length,
              (index) => GestureDetector(
                onTap: () => setState(() => _selectedColorIndex = index),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.memberColors[index],
                    shape: BoxShape.circle,
                    border: _selectedColorIndex == index ? Border.all(color: Theme.of(context).primaryColor, width: 2) : null,
                  ),
                  child: _selectedColorIndex == index ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                ),
              ),
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: AppTheme.spacingM),
            Text(_errorMessage!, style: const TextStyle(color: AppColors.errorLight, fontSize: 12), textAlign: TextAlign.center),
          ],
          const SizedBox(height: AppTheme.spacingL),
          ElevatedButton(
            onPressed: _isLoading ? null : _handleSubmit,
            child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(isCreate ? '생성하기' : '참여하기'),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView() {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLarge)),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Iconsax.tick_circle5, size: 64, color: AppColors.successLight),
            const SizedBox(height: AppTheme.spacingM),
            Text('그룹이 생성되었습니다!', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppTheme.spacingL),
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingM),
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              child: SelectableText(
                _newInviteCode!,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: AppColors.primaryLight, letterSpacing: 4),
              ),
            ),
            const SizedBox(height: AppTheme.spacingL),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('닫기')),
          ],
        ),
      ),
    );
  }
}

class _SelectionItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _SelectionItem({required this.icon, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        ),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).primaryColor),
            const SizedBox(width: AppTheme.spacingM),
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const Spacer(),
            const Icon(Iconsax.arrow_right_3, size: 16),
          ],
        ),
      ),
    );
  }
}
