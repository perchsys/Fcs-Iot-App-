import 'package:flutter/material.dart';
import 'package:iot_starter_kit_app/core/constants.dart';
import 'package:iot_starter_kit_app/core/services/settings_service.dart';
import 'package:iot_starter_kit_app/generated/locale_base.dart';
import 'package:iot_starter_kit_app/locator.dart';
import 'package:iot_starter_kit_app/utils/locale_delegate.dart';
import 'package:iot_starter_kit_app/utils/settings_helper.dart';
import 'package:pref/pref.dart';
import 'package:theme_provider/theme_provider.dart';

class SettingsScreen extends StatefulWidget {
  SettingsScreen({Key? key}) : super(key: key);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late LocaleBase lang;

  @override
  Widget build(BuildContext context) {
    lang = Localizations.of<LocaleBase>(context, LocaleBase)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(lang.ScreenSettings.settingsTitle),
      ),
      body: buildSettingsBody(context),
    );
  }

  /// construct the setting elements
  buildSettingsBody(BuildContext context) {
    final settingsService = locator.get<SettingsService>();

    // get saved language
    var savedLanguage =
        SettingsHelper.getSavedLanguage(PrefService.of(context));

    if (savedLanguage == null) {
      savedLanguage = LocaleDelegate.getLanguagesList().firstWhere((language) =>
          language.languageCode ==
          LocaleDelegate.getDeviceLocale().languageCode);
    }

    final currentLanguageKey = savedLanguage.localeKey;

    // construct the language selection
    final List<DropdownMenuItem<String>> dropdownMenuItems =
        LocaleDelegate.getLanguagesList()
            .map((lang) => DropdownMenuItem(
                value: lang.localeKey, child: Text(lang.localName!)))
            .toList();

    return PrefPage(
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: PrefTitle(title: Text(lang.ScreenSettings.sectionUISettings)),
        ),
        PrefDropdown<String>(
          title: Text(lang.ScreenSettings.languageLabel),
          pref: SettingsHelper.language,
          items: dropdownMenuItems,
          fullWidth: false,
          onChange: (value) {
            // check if same language was selected
            if (value == currentLanguageKey) return;

            // get locale by localeKey
            var newLocale =
                LocaleDelegate.getLanguageByLocaleKey(value)!.locale;

            // trigger the change language event
            settingsService.setAppLocale(newLocale);
          },
        ),
        PrefSwitch(
          title: Text(lang.ScreenSettings.enableDarkTheme),
          pref: SettingsHelper.enable_dark_theme,
          onChange: (value) {
            value
                ? ThemeProvider.controllerOf(context).setTheme('dark')
                : ThemeProvider.controllerOf(context).setTheme('light');
          },
        ),
        Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child:
              PrefTitle(title: Text(lang.ScreenSettings.sectionMqttSettings)),
        ),
        PrefDialogButton(
          title: Text(lang.ScreenSettings.mqttCredentials),
          trailing: Icon(Icons.chevron_right),
          onSubmit: () {
            // send new broker to the stream to trigger a reconnect event
            settingsService.setMqttSettings(
              PrefService.of(context).get<String>(SettingsHelper.mqtt_broker)!,
            );
          },
          dialog: PrefDialog(
            children: [
              PrefText(
                label: lang.ScreenSettings.mqttBroker,
                pref: SettingsHelper.mqtt_broker,
                padding: const EdgeInsets.only(top: 8.0),
                // autofocus: true,
                maxLines: 1,
                hintText: Constants.defaultMqttBroker,
                validator: (String? str) {
                  if (str == null || str.length == 0) {
                    return lang.ScreenSettings.mqttBrokerError1;
                  }

                  // check for valid domain or IP address
                  // var regex = RegExp(
                  //   r'/^[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.[a-zA-Z]{2,}$/',
                  // );
                  // if (!regex.hasMatch(str)) {
                  //   return "Broker must be a valid domain or IP";
                  // }

                  return null;
                },
              ),
              PrefText(
                label: lang.ScreenSettings.mqttPort,
                pref: SettingsHelper.mqtt_port,
                padding: const EdgeInsets.only(top: 8.0),
                maxLines: 1,
                hintText: Constants.defaultMqttPort,
                validator: (str) {
                  if (str == null || str.trim().length == 0) {
                    return lang.ScreenSettings.mqttPortError1;
                  }
                  var port = int.tryParse(str.trim());
                  if (port == null) {
                    return lang.ScreenSettings.mqttPortError2;
                  } else if (port > 65535) {
                    return lang.ScreenSettings.mqttPortError3;
                  }
                  return null;
                },
              ),
              PrefText(
                label: lang.ScreenSettings.mqttLogin,
                pref: SettingsHelper.mqtt_login,
                padding: const EdgeInsets.only(top: 8.0),
                maxLines: 1,
                hintText: 'mqtt_username',
              ),
              PrefText(
                label: lang.ScreenSettings.mqttPassword,
                pref: SettingsHelper.mqtt_password,
                padding: const EdgeInsets.only(top: 8.0),
                obscureText: true,
                maxLines: 1,
              ),
            ],
            title: Text(lang.ScreenSettings.mqttCredentials),
            cancel: Text(lang.ScreenSettings.buttonCancel),
            submit: Text(lang.ScreenSettings.buttonSave),
            onlySaveOnSubmit: true,
          ),
        ),
        PrefDialogButton(
          // dialog for device ID
          title: Text(lang.ScreenSettings.iotDeviceID),
          trailing: Icon(Icons.chevron_right),
          onSubmit: () {
            // send a trigger a reconnect event
            settingsService.setMqttSettings(
              PrefService.of(context).get<String>(SettingsHelper.device_id)!,
            );
          },
          dialog: PrefDialog(
            children: [
              PrefText(
                label: lang.ScreenSettings.iotDeviceID,
                pref: SettingsHelper.device_id,
                padding: const EdgeInsets.only(top: 8.0),
                // autofocus: true,
                maxLines: 1,
                hintText: Constants.defaultMqttDeviceId,
                validator: (String? str) {
                  if (str == null || str.trim().length == 0) {
                    return lang.ScreenSettings.iotDeviceIDError;
                  }
                  return null;
                },
              ),
            ],
            title: Text(lang.ScreenSettings.iotDeviceID),
            cancel: Text(lang.ScreenSettings.buttonCancel),
            submit: Text(lang.ScreenSettings.buttonSave),
            onlySaveOnSubmit: true,
          ),
        ),
        PrefSwitch(
          title: Text(lang.ScreenSettings.mqttShowLogEntries),
          pref: SettingsHelper.show_log,
        ),
        ListTile(
          // get version info from shared preferences (set on app launch)
          title: Text(PrefService.of(context)
              .get<String>(SettingsHelper.app_version_string)!),
          enabled: false,
        ),
      ],
    );
  }
}
