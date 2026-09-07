import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'dart:convert';

import 'widgets/theme.dart';
import 'screens/language_screen.dart';
import 'screens/login_screen.dart';
import 'screens/menu_screen.dart';
import 'services/license_service.dart';
import 'models/license_model.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarBrightness: Brightness.dark,
      statusBarColor: Colors.transparent,
    ),
  );
  runApp(const FFExternalApp());
}

class FFExternalApp extends StatefulWidget {
  const FFExternalApp({super.key});

  @override
  State<FFExternalApp> createState() => _FFExternalAppState();
}

class _FFExternalAppState extends State<FFExternalApp> {
  String _locale = 'en';

  void _setLocale(String code) => setState(() => _locale = code);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FF External',
      debugShowCheckedModeBanner: false,
      theme: FFTheme.theme,
      locale: Locale(_locale),
      supportedLocales: const [
        Locale('en'),
        Locale('id'),
        Locale('pt'),
        Locale('vi'),
        Locale('zh'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: RootNavigator(onLocaleChange: _setLocale),
    );
  }
}

enum _AppStage { language, login, menu }

class RootNavigator extends StatefulWidget {
  final ValueChanged<String> onLocaleChange;
  const RootNavigator({super.key, required this.onLocaleChange});

  @override
  State<RootNavigator> createState() => _RootNavigatorState();
}

class _RootNavigatorState extends State<RootNavigator> {
  _AppStage _stage = _AppStage.language;
  String _langCode = 'en';
  String _deviceId = '';
  String? _licenseKey;
  LicenseResponse? _license;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _deviceId = await _getDeviceId();
    // check saved key
    final saved = await LicenseService.getSavedKey();
    if (saved != null) {
      try {
        final res = await LicenseService.validate(
            key: saved, deviceId: _deviceId);
        if (res.isActive && !res.isExpired) {
          setState(() {
            _licenseKey = saved;
            _license = res;
            _stage = _AppStage.menu;
          });
          return;
        } else {
          await LicenseService.clearKey();
        }
      } catch (_) {}
    }
    // no valid saved key — show language screen
    setState(() => _stage = _AppStage.language);
  }

  Future<String> _getDeviceId() async {
    try {
      final info = DeviceInfoPlugin();
      if (Platform.isIOS) {
        final ios = await info.iosInfo;
        final raw = ios.identifierForVendor ?? ios.utsname.machine;
        final bytes = utf8.encode(raw);
        return sha256.convert(bytes).toString().substring(0, 16).toUpperCase();
      }
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString('ff_device_id');
    if (id == null) {
      id = DateTime.now().millisecondsSinceEpoch.toRadixString(16).toUpperCase();
      await prefs.setString('ff_device_id', id);
    }
    return id;
  }

  @override
  Widget build(BuildContext context) {
    switch (_stage) {
      case _AppStage.language:
        return LanguageScreen(
          onLanguageSelected: (code) {
            setState(() {
              _langCode = code;
              _stage = _AppStage.login;
            });
            widget.onLocaleChange(code);
          },
        );

      case _AppStage.login:
        return LoginScreen(
          languageCode: _langCode,
          deviceId: _deviceId,
          onSuccess: (result) {
            setState(() {
              _licenseKey = result.key;
              _license = result.license;
              _stage = _AppStage.menu;
            });
          },
        );

      case _AppStage.menu:
        return MenuScreen(
          licenseKey: _licenseKey!,
          license: _license!,
          deviceId: _deviceId,
        );
    }
  }
}
