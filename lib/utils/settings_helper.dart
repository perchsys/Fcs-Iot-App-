import 'package:iot_starter_kit_app/utils/locale_delegate.dart';
import 'package:pref/pref.dart';

class SettingsHelper {
  static const String app_version_string = 'app_version_string';
  static const String app_name = 'app_name';

  static const String language = 'language';
  static const String enable_dark_theme = 'enable_dark_theme';
  static const String show_log = 'show_log';
  static const String device_id = 'device_id';

  static const String mqtt_broker = 'mqtt_broker';
  static const String mqtt_port = 'mqtt_port';
  static const String mqtt_login = 'mqtt_login';
  static const String mqtt_password = 'mqtt_password';

  static Language? getSavedLanguage(BasePrefService prefService) {
    Language? savedLanguage;

    final savedLanguageKey = prefService.get<String>(language);

    // get language reference from the list of languages
    if (savedLanguageKey != null) {
      savedLanguage = LocaleDelegate.getLanguagesMap()[savedLanguageKey];
    }

    return savedLanguage;
  }

  /// Return temp. unit from settings
  static bool isMetric(String unit) {
    return unit == 'metric';
  }

  static String tempUnit(bool isMetric) {
    return isMetric ? '°C' : '°F';
  }
}
