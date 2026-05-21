import 'package:flutter/material.dart';

/// 全局 ScaffoldMessenger，用于登录/注册后页面切换时仍能显示 SnackBar。
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();
