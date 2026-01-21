import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:iconsax/iconsax.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = ref.read(authServiceProvider);
      await authService.signInWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
      );

    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String message = '로그인에 실패했습니다. 이메일과 비밀번호를 확인해주세요.';
      if (e.code == 'user-not-found') {
        message = '존재하지 않는 계정입니다.';
      } else if (e.code == 'wrong-password') {
        message = '비밀번호가 일치하지 않습니다.';
      } else if (e.code == 'invalid-email') {
        message = '유효하지 않은 이메일 형식입니다.';
      } else if (e.code == 'user-disabled') {
        message = '비활성화된 계정입니다.';
      }
      setState(() {
        _errorMessage = message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '로그인 중 오류가 발생했습니다.';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleGoogleLogin() async {
    setState(() {
      _isGoogleLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = ref.read(authServiceProvider);
      await authService.signInWithGoogle();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Google 로그인에 실패했습니다. 다시 시도해주세요.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isGoogleLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spacingL),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppTheme.spacingXXL),
                
                // 로고 및 타이틀
                Icon(
                  Iconsax.home_hashtag5,
                  size: 64,
                  color: AppColors.primaryLight,
                ),
                const SizedBox(height: AppTheme.spacingM),
                Text(
                  'BABBA',
                  style: Theme.of(context).textTheme.headlineLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppTheme.spacingS),
                Text(
                  '바쁜 일상을 함께',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isDark 
                        ? AppColors.textSecondaryDark 
                        : AppColors.textSecondaryLight,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: AppTheme.spacingXXL),

                // 에러 메시지
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spacingM),
                    decoration: BoxDecoration(
                      color: AppColors.errorLight.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Iconsax.warning_2,
                          color: AppColors.errorLight,
                          size: 20,
                        ),
                        const SizedBox(width: AppTheme.spacingS),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(
                              color: AppColors.errorLight,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingM),
                ],

                // 이메일 입력
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: '이메일',
                    prefixIcon: Icon(Iconsax.sms),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '이메일을 입력해주세요';
                    }
                    if (!value.contains('@')) {
                      return '올바른 이메일 형식이 아닙니다';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppTheme.spacingM),

                // 비밀번호 입력
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _handleLogin(),
                  decoration: InputDecoration(
                    labelText: '비밀번호',
                    prefixIcon: const Icon(Iconsax.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Iconsax.eye : Iconsax.eye_slash,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '비밀번호를 입력해주세요';
                    }
                    if (value.length < 6) {
                      return '비밀번호는 6자 이상이어야 합니다';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppTheme.spacingL),

                // 로그인 버튼
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('로그인'),
                  ),
                ),
                const SizedBox(height: AppTheme.spacingL),

                // 구분선
                Row(
                  children: [
                    Expanded(
                      child: Divider(
                        color: isDark 
                            ? AppColors.textSecondaryDark.withValues(alpha: 0.3)
                            : AppColors.textSecondaryLight.withValues(alpha: 0.3),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingM),
                      child: Text(
                        '또는',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isDark 
                              ? AppColors.textSecondaryDark 
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(
                        color: isDark 
                            ? AppColors.textSecondaryDark.withValues(alpha: 0.3)
                            : AppColors.textSecondaryLight.withValues(alpha: 0.3),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingL),

                // Google 로그인 버튼
                SizedBox(
                  height: 52,
                  child: OutlinedButton(
                    onPressed: _isGoogleLoading ? null : _handleGoogleLogin,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: isDark 
                            ? AppColors.textSecondaryDark.withValues(alpha: 0.3)
                            : AppColors.textSecondaryLight.withValues(alpha: 0.3),
                      ),
                    ),
                    child: _isGoogleLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Center(
                                  child: Text(
                                    'G',
                                    style: TextStyle(
                                      color: Colors.red.shade500,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppTheme.spacingS),
                              const Text('Google로 계속하기'),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: AppTheme.spacingL),

                // 회원가입 링크
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '계정이 없으신가요?',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    TextButton(
                      onPressed: () => context.go('/auth/signup'),
                      child: const Text('회원가입'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
