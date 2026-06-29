import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/app_messenger.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailController = TextEditingController();
  final _fullNameController = TextEditingController();
  bool _isLogin = true;
  bool _obscurePassword = true;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _emailController.dispose();
    _fullNameController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    bool success;
    if (_isLogin) {
      success =
          await auth.login(_usernameController.text.trim(), _passwordController.text);
    } else {
      success = await auth.register(
        username: _usernameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        fullName: _fullNameController.text.trim().isNotEmpty
            ? _fullNameController.text.trim()
            : null,
      );
    }

    if (!mounted) return;
    if (success) {
      final name = auth.user?.fullName ?? auth.user?.username;
      rootScaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('${_isLogin ? "登录" : "注册"}成功${name != null ? "，欢迎 $name" : ""}'),
          backgroundColor: AppTheme.success,
        ),
      );
      return;
    }
    rootScaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(auth.error ?? '操作失败'),
        backgroundColor: AppTheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.primary, AppTheme.primaryDark],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SingleChildScrollView(
              padding: EdgeInsets.all(AppTheme.spaceLg),
              child: Column(
                children: [
                  const SizedBox(height: 48),
                  // Logo
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: AppTheme.elevatedShadow,
                    ),
                    child: const Icon(
                      Icons.medical_services_outlined,
                      size: 44,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'MedExam AI',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'AI 驱动的医考学习平台',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(height: 48),
                  // 表单卡片
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(AppTheme.spaceLg),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                      boxShadow: AppTheme.elevatedShadow,
                    ),
                    child: Column(
                      children: [
                        Text(
                          _isLogin ? '欢迎回来' : '创建账号',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _isLogin ? '登录继续你的学习之旅' : '开启你的医考学习之旅',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 28),
                        Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              if (!_isLogin) ...[
                                _buildField(
                                  controller: _fullNameController,
                                  label: '姓名',
                                  hint: '你的姓名（选填）',
                                  icon: Icons.person_outline,
                                ),
                                const SizedBox(height: 14),
                                _buildField(
                                  controller: _emailController,
                                  label: '邮箱',
                                  hint: 'your@email.com',
                                  icon: Icons.email_outlined,
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (v) {
                                    if (!_isLogin && (v == null || v.isEmpty)) return '请输入邮箱';
                                    if (!_isLogin && !v!.contains('@')) return '邮箱格式不正确';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 14),
                              ],
                              _buildField(
                                controller: _usernameController,
                                label: '用户名',
                                hint: '输入用户名',
                                icon: Icons.account_circle_outlined,
                                validator: (v) {
                                  if (v == null || v.isEmpty) return '请输入用户名';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),
                              _buildField(
                                controller: _passwordController,
                                label: '密码',
                                hint: _isLogin ? '输入密码' : '至少 6 位密码',
                                icon: Icons.lock_outline,
                                obscure: _obscurePassword,
                                suffix: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    size: 20,
                                  ),
                                  onPressed: () => setState(
                                      () => _obscurePassword = !_obscurePassword),
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) return '请输入密码';
                                  if (!_isLogin && v.length < 6) return '密码至少 6 位';
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Consumer<AuthProvider>(
                          builder: (context, auth, _) {
                            return SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                onPressed: auth.isLoading ? null : _submit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(AppTheme.radiusMd),
                                  ),
                                ),
                                child: auth.isLoading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(
                                        _isLogin ? '登录' : '注册',
                                        style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _isLogin ? '还没有账号？' : '已有账号？',
                              style:
                                  const TextStyle(color: AppTheme.textSecondary),
                            ),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () {
                                setState(() => _isLogin = !_isLogin);
                                _animController.reset();
                                _animController.forward();
                              },
                              child: Text(
                                _isLogin ? '立即注册' : '去登录',
                                style: TextStyle(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Demo 账号: demo / demo123',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscure = false,
    Widget? suffix,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        suffixIcon: suffix,
      ),
    );
  }
}
