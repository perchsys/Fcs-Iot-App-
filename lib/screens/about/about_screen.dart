import 'package:about/about.dart';
import 'package:flutter/material.dart';
import 'package:iot_starter_kit_app/core/constants.dart';
import 'package:iot_starter_kit_app/generated/locale_base.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutScreen extends StatefulWidget {
  AboutScreen({Key? key}) : super(key: key);

  @override
  _AboutScreenState createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  late LocaleBase lang;
  PackageInfo? packageInfo;

  @override
  void initState() {
    // load app version info as mentioned in pubspec.yaml
    PackageInfo.fromPlatform().then((result) {
      setState(() {
        packageInfo = result;
      });
    });

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    lang = Localizations.of<LocaleBase>(context, LocaleBase)!;

    return Scaffold(
      body: AboutPage(
        values: {
          'version': packageInfo?.version ?? '1.0.0',
          'buildNumber': packageInfo?.buildNumber ?? '001',
          'year': DateTime.now().year.toString(),
        },
        title: Text(lang.ScreenAbout.aboutTitle),
        applicationVersion:
            'Version {{version}}, build {{buildNumber}} - ${Constants.appEdition}',
        applicationDescription: Text(
          lang.ScreenAbout.appDescription,
          textAlign: TextAlign.justify,
        ),
        applicationIcon: Padding(
          padding: const EdgeInsets.only(top: 12.0),
          child: Image.asset(
            'assets/logo/app_logo.png',
            alignment: Alignment.center,
            height: 80,
          ),
        ),
        applicationLegalese: '© My IoT Company, {{ year }}',
        children: <Widget>[
          ListTile(
            title: Text(lang.ScreenAbout.sayHelloLabel),
            leading: Icon(Icons.email),
            onTap: () async {
              var emailUrl =
                  'mailto:${lang.ScreenAbout.emailAddress}?subject=${lang.ScreenAbout.emailSubject}';

              if (await canLaunch(emailUrl)) {
                await launch(emailUrl);
              } else {
                throw 'Could not launch $emailUrl';
              }
            },
          ),
          ListTile(
            title: Text(lang.ScreenAbout.privacyPolicyLabel),
            leading: Icon(Icons.verified_user),
            onTap: () async {
              if (await canLaunch(lang.ScreenAbout.privacyPolicyUrl)) {
                await launch(
                  lang.ScreenAbout.privacyPolicyUrl,
                  forceWebView: true,
                  forceSafariVC: true,
                  enableJavaScript: true,
                );
              } else {
                throw 'Could not launch ${lang.ScreenAbout.privacyPolicyUrl}';
              }
            },
          ),
          MarkdownPageListTile(
            filename: 'assets/docs/readme.md',
            title: Text(lang.ScreenAbout.viewReadMe),
            icon: Icon(Icons.all_inclusive),
          ),
          MarkdownPageListTile(
            filename: 'assets/docs/change_log.md',
            title: Text(lang.ScreenAbout.viewChangelog),
            icon: Icon(Icons.view_list),
          ),
          MarkdownPageListTile(
            filename: 'assets/docs/license.md',
            title: Text(lang.ScreenAbout.viewLicense),
            icon: Icon(Icons.description),
          ),
          LicensesPageListTile(
            title: Text(lang.ScreenAbout.openSourceLicenses),
            icon: Icon(Icons.favorite),
          ),
        ],
      ),
    );
  }
}
