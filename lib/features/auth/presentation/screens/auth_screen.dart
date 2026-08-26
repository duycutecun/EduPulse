import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/supabase_service.dart';

class AuthScreen extends StatefulWidget {
  final VoidCallback onAuthSuccess;
  final VoidCallback onSkip;

  const AuthScreen({
    super.key,
    required this.onAuthSuccess,
    required this.onSkip,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  bool _obscurePw = true;
  bool _obscureConfirm = true;

  // Login controllers
  final _loginEmailCtrl = TextEditingController();
  final _loginPwCtrl = TextEditingController();

  // Register controllers
  final _regNameCtrl = TextEditingController();
  final _regEmailCtrl = TextEditingController();
  final _regPwCtrl = TextEditingController();
  final _regConfirmCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginEmailCtrl.dispose();
    _loginPwCtrl.dispose();
    _regNameCtrl.dispose();
    _regEmailCtrl.dispose();
    _regPwCtrl.dispose();
    _regConfirmCtrl.dispose();
    super.dispose();
  }

  void _showMessage(String msg, bool isSuccess) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Text(isSuccess ? '✅ ' : '⚠️ '),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: isSuccess
            ? AppColors.appleGreen.withValues(alpha: 0.9)
            : AppColors.appleRed.withValues(alpha: 0.9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _doLogin() async {
    final email = _loginEmailCtrl.text.trim();
    final pw = _loginPwCtrl.text;

    if (email.isEmpty || pw.isEmpty) {
      _showMessage('Vui lòng nhập đầy đủ email và mật khẩu.', false);
      return;
    }

    setState(() => _isLoading = true);
    final result = await SupabaseService.signIn(email: email, password: pw);
    setState(() => _isLoading = false);

    _showMessage(result.message, result.success);
    if (result.success) {
      await Future.delayed(const Duration(milliseconds: 800));
      widget.onAuthSuccess();
    }
  }

  Future<void> _doRegister() async {
    final name = _regNameCtrl.text.trim();
    final email = _regEmailCtrl.text.trim();
    final pw = _regPwCtrl.text;
    final confirm = _regConfirmCtrl.text;

    if (name.isEmpty || email.isEmpty || pw.isEmpty) {
      _showMessage('Vui lòng điền đầy đủ thông tin.', false);
      return;
    }
    if (pw != confirm) {
      _showMessage('Mật khẩu xác nhận không khớp!', false);
      return;
    }
    if (pw.length < 6) {
      _showMessage('Mật khẩu phải có ít nhất 6 ký tự.', false);
      return;
    }

    setState(() => _isLoading = true);
    final result = await SupabaseService.signUp(
      email: email,
      password: pw,
      name: name,
    );
    setState(() => _isLoading = false);

    _showMessage(result.message, result.success);
    if (result.success) {
      // Nếu có session ngay (không cần verify) thì callback thành công
      if (SupabaseService.isLoggedIn) {
        await Future.delayed(const Duration(milliseconds: 800));
        widget.onAuthSuccess();
      } else {
        // Chuyển sang tab đăng nhập
        _tabController.animateTo(0);
        _loginEmailCtrl.text = email;
      }
    }
  }

  Future<void> _doResetPassword() async {
    final email = _loginEmailCtrl.text.trim();
    if (email.isEmpty) {
      _showMessage('Nhập email của bạn trước, sau đó nhấn Quên mật khẩu.', false);
      return;
    }
    setState(() => _isLoading = true);
    final result = await SupabaseService.resetPassword(email);
    setState(() => _isLoading = false);
    _showMessage(result.message, result.success);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0E0D1B) : const Color(0xFFF5F5F7),
      body: Stack(
        children: [
          // Background gradient blobs
          Positioned(
            top: -60,
            left: -40,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppColors.appleIndigo.withValues(alpha: 0.35),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            right: -60,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppColors.appleBlue.withValues(alpha: 0.25),
                  Colors.transparent,
                ]),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: size.height - 80),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 32),

                    // Logo & Title
                    const Text('🎓', style: TextStyle(fontSize: 52)),
                    const SizedBox(height: 12),
                    Text(
                      'EduPulse',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Trợ lý Sĩ tử • Đếm ngược Kỳ thi',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white60 : Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Tab Switcher
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.06)
                                : Colors.white.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark ? Colors.white12 : Colors.black12,
                            ),
                          ),
                          child: Column(
                            children: [
                              // Tab bar
                              Container(
                                margin: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.06)
                                      : Colors.black.withValues(alpha: 0.04),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: TabBar(
                                  controller: _tabController,
                                  indicator: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [AppColors.appleIndigo, AppColors.appleBlue],
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  indicatorSize: TabBarIndicatorSize.tab,
                                  dividerColor: Colors.transparent,
                                  labelColor: Colors.white,
                                  unselectedLabelColor:
                                      isDark ? Colors.white60 : Colors.black54,
                                  labelStyle: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                  tabs: const [
                                    Tab(text: '🔐  Đăng nhập'),
                                    Tab(text: '✨  Đăng ký'),
                                  ],
                                ),
                              ),

                              // Tab content
                              SizedBox(
                                height: _tabController.index == 0 ? 290 : 360,
                                child: TabBarView(
                                  controller: _tabController,
                                  children: [
                                    _buildLoginForm(isDark),
                                    _buildRegisterForm(isDark),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Primary Action Button
                    AnimatedBuilder(
                      animation: _tabController,
                      builder: (context, _) {
                        final isLogin = _tabController.index == 0;
                        return GestureDetector(
                          onTap: _isLoading
                              ? null
                              : (isLogin ? _doLogin : _doRegister),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              gradient: _isLoading
                                  ? LinearGradient(colors: [
                                      AppColors.appleIndigo.withValues(alpha: 0.5),
                                      AppColors.appleBlue.withValues(alpha: 0.5),
                                    ])
                                  : const LinearGradient(
                                      colors: [AppColors.appleIndigo, AppColors.appleBlue],
                                    ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.appleIndigo.withValues(alpha: 0.4),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Center(
                              child: _isLoading
                                  ? const CupertinoActivityIndicator(color: Colors.white)
                                  : Text(
                                      isLogin ? '🔐  Đăng nhập' : '🚀  Tạo tài khoản',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // Skip / Guest mode
                    GestureDetector(
                      onTap: widget.onSkip,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isDark ? Colors.white24 : Colors.black26,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Text(
                            'Tiếp tục không cần tài khoản →',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    Text(
                      'Chế độ khách: Dữ liệu chỉ lưu trên thiết bị này.\nĐăng ký để sao lưu & dùng trên nhiều thiết bị.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? Colors.white38 : Colors.black38,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          _authField(
            ctrl: _loginEmailCtrl,
            label: 'Email',
            icon: CupertinoIcons.mail,
            keyboard: TextInputType.emailAddress,
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          _authField(
            ctrl: _loginPwCtrl,
            label: 'Mật khẩu',
            icon: CupertinoIcons.lock,
            obscure: _obscurePw,
            isDark: isDark,
            suffix: GestureDetector(
              onTap: () => setState(() => _obscurePw = !_obscurePw),
              child: Icon(
                _obscurePw ? CupertinoIcons.eye : CupertinoIcons.eye_slash,
                size: 18,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _doResetPassword,
            child: const Text(
              'Quên mật khẩu?',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.appleBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterForm(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        children: [
          const SizedBox(height: 8),
          _authField(
            ctrl: _regNameCtrl,
            label: 'Tên / Biệt danh Sĩ tử',
            icon: CupertinoIcons.person,
            isDark: isDark,
          ),
          const SizedBox(height: 10),
          _authField(
            ctrl: _regEmailCtrl,
            label: 'Email',
            icon: CupertinoIcons.mail,
            keyboard: TextInputType.emailAddress,
            isDark: isDark,
          ),
          const SizedBox(height: 10),
          _authField(
            ctrl: _regPwCtrl,
            label: 'Mật khẩu (≥6 ký tự)',
            icon: CupertinoIcons.lock,
            obscure: _obscurePw,
            isDark: isDark,
            suffix: GestureDetector(
              onTap: () => setState(() => _obscurePw = !_obscurePw),
              child: Icon(
                _obscurePw ? CupertinoIcons.eye : CupertinoIcons.eye_slash,
                size: 18,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
            ),
          ),
          const SizedBox(height: 10),
          _authField(
            ctrl: _regConfirmCtrl,
            label: 'Xác nhận mật khẩu',
            icon: CupertinoIcons.lock_shield,
            obscure: _obscureConfirm,
            isDark: isDark,
            suffix: GestureDetector(
              onTap: () => setState(() => _obscureConfirm = !_obscureConfirm),
              child: Icon(
                _obscureConfirm ? CupertinoIcons.eye : CupertinoIcons.eye_slash,
                size: 18,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _authField({
    required TextEditingController ctrl,
    required String label,
    required IconData icon,
    required bool isDark,
    TextInputType keyboard = TextInputType.text,
    bool obscure = false,
    Widget? suffix,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.07)
            : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black12,
        ),
      ),
      child: TextField(
        controller: ctrl,
        keyboardType: keyboard,
        obscureText: obscure,
        style: TextStyle(
          fontSize: 14,
          color: isDark ? Colors.white : Colors.black87,
        ),
        decoration: InputDecoration(
          prefixIcon: Icon(icon,
              size: 18,
              color: isDark ? Colors.white54 : Colors.black45),
          suffixIcon: suffix != null
              ? Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: suffix,
                )
              : null,
          hintText: label,
          hintStyle: TextStyle(
            fontSize: 13.5,
            color: isDark ? Colors.white38 : Colors.black38,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 13,
          ),
        ),
      ),
    );
  }
}
