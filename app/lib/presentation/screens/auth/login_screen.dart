import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/providers/auth_provider.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/app_messenger.dart';
import '../../widgets/app_glass.dart';

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
  final _phoneController = TextEditingController();
  final _smsCodeController = TextEditingController();
  final _fullNameController = TextEditingController();
  bool _isLogin = true;
  bool _useSmsLogin = true;
  bool _obscurePassword = true;
  bool _isSendingSms = false;
  int _smsCooldownSeconds = 0;
  Timer? _smsCooldownTimer;
  String _targetExam = AppConstants.examCategories.first;
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
    _phoneController.dispose();
    _smsCodeController.dispose();
    _fullNameController.dispose();
    _smsCooldownTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    bool success;
    if (_isLogin) {
      if (_useSmsLogin) {
        success = await auth.loginWithSms(
          phone: _usernameController.text.trim(),
          smsCode: _smsCodeController.text.trim(),
        );
      } else {
        success = await auth.login(
            _usernameController.text.trim(), _passwordController.text);
      }
    } else {
      success = await auth.register(
        phone: _phoneController.text.trim(),
        smsCode: _smsCodeController.text.trim(),
        password: _passwordController.text,
        targetExam: _targetExam,
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
          content: Text(
              '${_isLogin ? "登录" : "注册"}成功${name != null ? "，欢迎 $name" : ""}'),
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

  Future<void> _sendSmsCode() async {
    if (_isSendingSms || _smsCooldownSeconds > 0) return;
    final phone =
        (_isLogin ? _usernameController.text : _phoneController.text).trim();
    if (phone.length != 11 || int.tryParse(phone) == null) {
      rootScaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('请输入正确的 11 位手机号'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }
    setState(() => _isSendingSms = true);
    final code = await context
        .read<AuthProvider>()
        .sendSmsCode(phone, purpose: _isLogin ? 'login' : 'register');
    if (!mounted) return;
    setState(() => _isSendingSms = false);
    if (code != null) {
      _smsCodeController.text = code;
      _startSmsCooldown();
      rootScaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('验证码已发送。本地演示验证码：$code'),
          backgroundColor: AppTheme.success,
        ),
      );
    } else {
      final error = context.read<AuthProvider>().error ?? '验证码发送失败';
      rootScaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppTheme.error),
      );
    }
  }

  void _startSmsCooldown() {
    _smsCooldownTimer?.cancel();
    setState(() => _smsCooldownSeconds = 60);
    _smsCooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_smsCooldownSeconds <= 1) {
        timer.cancel();
        setState(() => _smsCooldownSeconds = 0);
      } else {
        setState(() => _smsCooldownSeconds--);
      }
    });
  }

  void _resetSmsState() {
    _smsCooldownTimer?.cancel();
    _smsCooldownSeconds = 0;
    _isSendingSms = false;
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              AppTheme.spaceLg,
              AppTheme.spaceLg,
              AppTheme.spaceLg,
              AppTheme.spaceLg + 36,
            ),
            child: Column(
              children: [
                const SizedBox(height: 16),
                // Logo
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.86),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: AppTheme.elevatedShadow,
                    border: Border.all(color: Colors.white.withOpacity(0.9)),
                  ),
                  child: const Icon(
                    Icons.medical_services_outlined,
                    size: 36,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'MedExam AI',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'AI 驱动的医考学习平台',
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                // 表单卡片
                GlassCard(
                  width: double.infinity,
                  padding: EdgeInsets.all(AppTheme.spaceMd),
                  radius: AppTheme.radiusXl,
                  tint: Colors.white.withOpacity(0.82),
                  borderColor: Colors.white.withOpacity(0.92),
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
                      const SizedBox(height: 20),
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
                              const SizedBox(height: 12),
                              _buildField(
                                controller: _phoneController,
                                label: '手机号',
                                hint: '请输入手机号',
                                icon: Icons.phone_iphone_rounded,
                                keyboardType: TextInputType.phone,
                                validator: (v) {
                                  if (!_isLogin && (v == null || v.isEmpty)) {
                                    return '请输入手机号';
                                  }
                                  if (!_isLogin &&
                                      (v!.length != 11 ||
                                          int.tryParse(v) == null)) {
                                    return '手机号格式不正确';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              _buildTargetExamSelector(),
                              const SizedBox(height: 12),
                              _buildField(
                                controller: _smsCodeController,
                                label: '手机验证码',
                                hint: '请输入验证码',
                                icon: Icons.verified_outlined,
                                keyboardType: TextInputType.number,
                                suffix: _buildSmsCodeButton(),
                                validator: (v) {
                                  if (!_isLogin && (v == null || v.isEmpty)) {
                                    return '请输入验证码';
                                  }
                                  if (!_isLogin && v!.length != 6) {
                                    return '验证码为 6 位';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                            ],
                            if (_isLogin) ...[
                              _buildField(
                                controller: _usernameController,
                                label: '手机号',
                                hint: '请输入手机号',
                                icon: Icons.phone_iphone_rounded,
                                keyboardType: TextInputType.phone,
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return '请输入手机号';
                                  }
                                  if (v.length != 11 ||
                                      int.tryParse(v) == null) {
                                    return '手机号格式不正确';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              _buildLoginModeSwitch(),
                              const SizedBox(height: 12),
                            ],
                            if (_isLogin && _useSmsLogin) ...[
                              _buildField(
                                controller: _smsCodeController,
                                label: '手机验证码',
                                hint: '请输入验证码',
                                icon: Icons.verified_outlined,
                                keyboardType: TextInputType.number,
                                suffix: _buildSmsCodeButton(),
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return '请输入验证码';
                                  }
                                  if (v.length != 6) {
                                    return '验证码为 6 位';
                                  }
                                  return null;
                                },
                              ),
                            ] else ...[
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
                                  onPressed: () => setState(() =>
                                      _obscurePassword = !_obscurePassword),
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return '请输入密码';
                                  }
                                  if (!_isLogin && v.length < 6) {
                                    return '密码至少 6 位';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (_isLogin) ...[
                        _buildDemoAccountButton(),
                        const SizedBox(height: 12),
                      ],
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
                      const SizedBox(height: 12),
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
                              setState(() {
                                _isLogin = !_isLogin;
                                _useSmsLogin = _isLogin;
                                _smsCodeController.clear();
                                _passwordController.clear();
                                _resetSmsState();
                              });
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDemoAccountButton() {
    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      onTap: () {
        setState(() {
          _isLogin = true;
          _useSmsLogin = false;
          _usernameController.text = '13800000000';
          _passwordController.text = 'demo123';
          _smsCodeController.clear();
          _resetSmsState();
        });
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.primary.withOpacity(0.18)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_circle_outlined,
              size: 18,
              color: AppTheme.primary,
            ),
            SizedBox(width: 8),
            Text(
              '使用演示账号 13800000000 / demo123',
              style: TextStyle(
                color: AppTheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmsCodeButton() {
    final disabled = _isSendingSms || _smsCooldownSeconds > 0;
    final label = _isSendingSms
        ? '发送中...'
        : _smsCooldownSeconds > 0
            ? '${_smsCooldownSeconds}s'
            : '获取验证码';
    return TextButton(
      onPressed: disabled ? null : _sendSmsCode,
      child: Text(label),
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

  Widget _buildLoginModeSwitch() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.primary.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          _buildLoginModeItem(
            selected: _useSmsLogin,
            icon: Icons.sms_outlined,
            label: '验证码登录',
            onTap: () => setState(() {
              _useSmsLogin = true;
              _passwordController.clear();
              _resetSmsState();
            }),
          ),
          _buildLoginModeItem(
            selected: !_useSmsLogin,
            icon: Icons.lock_outline,
            label: '密码登录',
            onTap: () => setState(() {
              _useSmsLogin = false;
              _smsCodeController.clear();
              _resetSmsState();
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetExamSelector() {
    return DropdownButtonFormField<String>(
      value: _targetExam,
      decoration: const InputDecoration(
        labelText: '考试分类',
        prefixIcon: Icon(Icons.category_outlined, size: 20),
      ),
      items: AppConstants.examCategories
          .map((category) => DropdownMenuItem(
                value: category,
                child: Text(category),
              ))
          .toList(),
      onChanged: (value) {
        if (value == null) return;
        setState(() => _targetExam = value);
      },
    );
  }

  Widget _buildLoginModeItem({
    required bool selected,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(
                    colors: [AppTheme.primary, AppTheme.accent],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  )
                : null,
            color: selected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(15),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppTheme.primary.withOpacity(0.24),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 17,
                color: selected ? Colors.white : AppTheme.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? Colors.white : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
