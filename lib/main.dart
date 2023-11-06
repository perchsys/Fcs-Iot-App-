import 'package:flutter/scheduler.dart';
import 'package:iot_starter_kit_app/core/constants.dart';
import 'package:iot_starter_kit_app/core/services/settings_service.dart';
import 'package:iot_starter_kit_app/locator.dart';
import 'package:iot_starter_kit_app/screens/splash/splash_screen.dart';
import 'package:iot_starter_kit_app/ui/app_themes.dart';
import 'package:iot_starter_kit_app/utils/settings_helper.dart';
import 'package:iot_starter_kit_app/utils/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:iot_starter_kit_app/screen_router.dart';
import 'package:iot_starter_kit_app/utils/locale_delegate.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pref/pref.dart';
import 'package:theme_provider/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // set app debug mode
  Utils.appDebugMode = false;

  // set screen orientation lock
  Utils.setScreenOrientationPortrait();

  // preferences service (uses share_preferences)
  final prefService = await PrefServiceShared.init(
    prefix: 'pref_',
  );

  var packageInfo = await PackageInfo.fromPlatform();
  var versionString =
      '${Constants.appName} v${packageInfo.version} - ${Constants.appEdition}';

  // detect first time app launch
  if (prefService.get<String>('app_name') == null) {
    // set defaults if any
    prefService.setDefaultValues({'app_name': packageInfo.appName});

    // set default MQTT parameters
    prefService.setDefaultValues({
      SettingsHelper.mqtt_broker: Constants.defaultMqttBroker,
    });
    prefService.setDefaultValues({
      SettingsHelper.mqtt_port: Constants.defaultMqttPort,
    });
    prefService.setDefaultValues({
      SettingsHelper.device_id: Constants.defaultMqttDeviceId,
    });
    prefService.setDefaultValues({
      SettingsHelper.show_log: false,
    });
  }

  prefService.set<String>('app_version_string', versionString);

  // Covering old version of apps-config to have default DeviceId when upgraded
  if (prefService.get<String>(SettingsHelper.device_id) == null) {
    prefService.setDefaultValues({
      SettingsHelper.device_id: Constants.defaultMqttDeviceId,
    });
  }

  // Handle calls from debugPrint
  // Release mode: suppress messages with empty callback
  // Debug mode: timestamp and app info to messages
  var logMessageAppInfo = '${packageInfo.appName} ${packageInfo.version}';

  if (Utils.buildDebugMode) {
    debugPrint = (String? message, {int? wrapWidth}) {
      // add timestamp and app info to messages
      String formattedDate = DateFormat('EEE dd-MMM-yyyy kk:mm:ss').format(
        DateTime.now(),
      );
      var newMessage = "[$logMessageAppInfo, $formattedDate]: $message";

      debugPrintSynchronously(newMessage, wrapWidth: wrapWidth);
    };
  } else {
    // suppress the print messages in release mode
    debugPrint = (String? message, {int? wrapWidth}) {};
  }

  // setup service locator
  setupLocator();

  // start the app
  runApp(
    PrefService(
      service: prefService,
      child: MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late Locale appLocale;

  @override
  void initState() {
    super.initState();

    Future.delayed(Duration.zero).then((_) async {
      // log app startup event
      // await analytics.logAppOpen();
    });
  }

  @override
  Widget build(BuildContext context) {
    final settingsService = locator.get<SettingsService>();

    // set language from settings or revert to default
    var lang = SettingsHelper.getSavedLanguage(PrefService.of(context));
    if (lang != null) {
      appLocale = lang.locale;
    } else {
      appLocale = LocaleDelegate.getDeviceLocale();

      // save default language - blank screen bug
      String? language = appLocale.languageCode;
      if (appLocale.countryCode != '') {
        language += '-' + appLocale.countryCode!;
      }
      PrefService.of(context).setDefaultValues(
        {SettingsHelper.language: language},
      );
    }

    // send appLocale to app state (stream/sink)
    settingsService.setAppLocale(appLocale);

    // setup theme provider
    return ThemeProvider(
      saveThemesOnChange: true,
      // loadThemeOnInit: true,
      onInitCallback: (controller, previouslySavedThemeFuture) async {
        String? savedTheme = await previouslySavedThemeFuture;
        if (savedTheme != null) {
          controller.setTheme(savedTheme);
        } else {
          Brightness platformBrightness =
              SchedulerBinding.instance.window.platformBrightness;
          if (platformBrightness == Brightness.dark) {
            controller.setTheme('dark');
            savedTheme = 'dark';
          } else {
            controller.setTheme('light');
            savedTheme = 'light';
          }
          controller.forgetSavedTheme();
        }
        PrefService.of(context).setDefaultValues({
          SettingsHelper.enable_dark_theme: (savedTheme == 'dark'),
        });
      },
      themes: <AppTheme>[
        AppTheme(
          id: 'light',
          description: 'Light Theme',
          data: AppThemes.lightTheme,
        ),
        AppTheme(
          id: 'dark',
          description: 'Dark Theme',
          data: AppThemes.darkTheme,
        ),
      ],
      child: ThemeConsumer(
        child: Builder(builder: (themeContext) {
          return StreamBuilder<Locale>(
            initialData: appLocale,
            stream: locator<SettingsService>().appLocale,
            builder: (BuildContext context, AsyncSnapshot snapshot) {
              if (snapshot.hasData) {
                appLocale = snapshot.data;
              }

              return MaterialApp(
                debugShowCheckedModeBanner: false,
                title: Constants.titleHome,
                theme: ThemeProvider.themeOf(themeContext).data,
                localizationsDelegates:
                    LocaleDelegate.getLocalizationsDelegates(),
                supportedLocales: LocaleDelegate.getSupportedLocales(),
                locale: appLocale,
                onGenerateRoute: ScreenRouter.onGenerateRoute,
                home: SplashScreen(
                  afterSplashRoute: ScreenRouter.home,
                  secondsDelay: 1,
                ),
              );
            },
          );
        }),
      ),
    );
  }
}
