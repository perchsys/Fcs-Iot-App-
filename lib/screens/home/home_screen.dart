import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:iot_starter_kit_app/core/constants.dart';
import 'package:iot_starter_kit_app/core/services/mqtt_service.dart';
import 'package:iot_starter_kit_app/core/services/settings_service.dart';
import 'package:iot_starter_kit_app/generated/locale_base.dart';
import 'package:iot_starter_kit_app/locator.dart';
import 'package:iot_starter_kit_app/screens/home/side_menu.dart';
import 'package:iot_starter_kit_app/utils/settings_helper.dart';
import 'package:iot_starter_kit_app/widgets/button_expanded.dart';
import 'package:iot_starter_kit_app/ui/ui_helpers.dart';
import 'package:iot_starter_kit_app/widgets/double_back_to_close_app.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:pref/pref.dart';

class CustomLineChart extends StatelessWidget {
  final List<double> dataPoints;
  final String dataCaption;
  final String chartLabel;
  final double borderRadius;
  final Color backgroundColor;
  final List<Color> gradientColors;
  final TextStyle captionTextStyle;
  final TextStyle labelStyle; // Add the labelStyle parameter here

  CustomLineChart({
    required this.dataPoints,
    required this.dataCaption,
    required this.chartLabel,
    required this.borderRadius,
    required this.backgroundColor,
    required this.gradientColors,
    required this.captionTextStyle,
    required this.labelStyle, // Add the required labelStyle parameter here
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          chartLabel, // Display the chartLabel text
          style: labelStyle, // Use the labelStyle for styling the chartLabel
        ),
        // Your chart implementation
        Text(
          dataCaption,
          style: captionTextStyle,
        ),
      ],
    );
  }
}

class HomeScreen extends StatefulWidget {
  HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class LogEntry {
  final String? logText;
  final DateTime? logTime;
  final EspEventType? logType;
  LogEntry({this.logType, this.logText, this.logTime});
}

class _HomeScreenState extends State<HomeScreen> {
  late LocaleBase lang;
  final double cornerRadius = 6;
  late ThemeData theme;
  late Timer connectionTimer;

  late StreamSubscription<MqttConnectionState> mqttConnectionStateSubscription;
  late StreamSubscription<EspMessage> espMessageSubscription;
  late StreamSubscription<String> settingsSubscription;

  final settingsService = locator.get<SettingsService>();
  final mqttService = locator.get<MqttService>();

  List<LogEntry> eventLog = [];

  DataModel? dataModel;

  List<double> tempData = [0, 0, 0, 0, 0, 0];
  String tempUnit = "C";
  List<double> humidData = [0, 0, 0, 0, 0, 0];
  bool port1Status =
      true; // Port1 closes in 500ms automatically after open command
  bool port2Status = false;
  bool pingStatus = true;
  bool beepStatus = true;

  String deviceUptime = "0:00:00:00";

  String? mqttBroker;
  int? mqttPort;
  String? mqttLogin;
  String? mqttPassword;

  // default ESP device ID
  String? deviceId;

  @override
  void initState() {
    super.initState();

    // subscribe to connection state stream
    mqttConnectionStateSubscription =
        mqttService.mqttConnectionStateStream.listen(null);
    mqttConnectionStateSubscription.onData(onMqttConnectionState);

    // subscribe to ESP Message stream
    espMessageSubscription = mqttService.espMessageStream.listen(null);
    espMessageSubscription.onData(onEspMessage);

    // subscribe to settings service stream
    settingsSubscription = settingsService.mqttSettings.listen(null);
    settingsSubscription.onData(onSettingsData);

    // trigger the connection routine after layout is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // start timer to check connection status and
      // to request new sensor data every five seconds
      connectionTimer =
          new Timer.periodic(Duration(seconds: 5), onTimerCallback);

      onTimerCallback(null);
    });
  }

  @override
  void dispose() {
    mqttConnectionStateSubscription.cancel();
    espMessageSubscription.cancel();
    settingsSubscription.cancel();
    super.dispose();
  }

  bool ifConnected() {
    return mqttService.connectionState == MqttConnectionState.connected;
  }

  /// Load MQTT credentials from settings
  loadMqttCredentials() {
    // load mqtt credentials
    mqttBroker =
        PrefService.of(context).get<String>(SettingsHelper.mqtt_broker);
    mqttPort = int.parse(
        PrefService.of(context).get<String>(SettingsHelper.mqtt_port) ??
            "1883");
    mqttLogin = PrefService.of(context).get<String>(SettingsHelper.mqtt_login);
    mqttPassword =
        PrefService.of(context).get<String>(SettingsHelper.mqtt_password);

    // set default device ID
    deviceId = PrefService.of(context).get<String>(SettingsHelper.device_id);
    if (deviceId == null || deviceId!.length == 0) {
      deviceId = Constants.defaultMqttDeviceId;
    }
  }

  /// Connect mqttService
  connectMqttService() {
    if (mqttService.connectionState == MqttConnectionState.disconnected) {
      loadMqttCredentials();

      // connect mqtt service
      mqttService.connect(
        mqttBroker: mqttBroker,
        port: mqttPort,
        login: mqttLogin,
        password: mqttPassword,
        deviceId: deviceId,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    lang = Localizations.of<LocaleBase>(context, LocaleBase)!;
    theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: buildAppBar(context),
      drawer: SideMenu(deviceUptime: deviceUptime),
      body: DoubleBackToCloseApp(
        snackBar: UIHelper.getSnackBar(
          message: Text(
            lang.Common.popupBackToExit,
            style: TextStyle(color: Colors.white),
          ),
          bgColor: theme.snackBarTheme.backgroundColor!,
        ),
        child: Container(
          color: theme.scaffoldBackgroundColor,
          padding: const EdgeInsets.only(
            left: UIHelper.HorizontalSpaceVerySmall,
            right: UIHelper.HorizontalSpaceVerySmall,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              UIHelper.verticalSpaceVerySmall(),
              // First expanded section
              // Expanded(
              //   flex: 25,
              //   child: Container(
              //     child: buildGraph(context),
              //   ),
              // ),
              UIHelper.verticalSpaceVerySmall(),
              // Second expanded section
              Expanded(
                flex: 25,
                child: Container(
                  child: buildGraphs(context),
                ),
              ),
              UIHelper.verticalSpaceVerySmall(),
            ],
          ),
        ),
      ),
    );
  }

  /// build app bar with title and connection state
  AppBar? buildAppBar(BuildContext context) {
    return AppBar(
      title: Text(Constants.titleHome),
      actions: <Widget>[
        // build UI for Connection State
        // where is your project ?
        StreamBuilder<MqttConnectionState>(
          stream: mqttService.mqttConnectionStateStream,
          builder: (context, snapshot) {
            return Container(
              padding: EdgeInsets.only(right: 6),
              child: Center(
                child: (snapshot.data == MqttConnectionState.connected)
                    ? IconButton(
                        icon: Icon(
                          Icons.refresh,
                          size: 35,
                        ),
                        onPressed:
                            (snapshot.data == MqttConnectionState.connected)
                                ? () {
                                    mqttService.disconnect();
                                  }
                                : () {},
                      )
                    : Padding(
                        padding: EdgeInsets.only(top: 2, right: 8),
                        child: SizedBox(
                          height: 5,
                          width: 25,
                          child: CircularProgressIndicator(strokeWidth: 3),
                        ),
                      ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget buildGraphs(BuildContext context) {
    return SingleChildScrollView(
      child: SizedBox(
        height: 400,
        child: Column(
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    flex: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(2.0),
                      child: Material(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(cornerRadius),
                        ),
                        color: Color.fromARGB(255, 16, 17, 15),
                        elevation: 1.5,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: CustomLineChart(
                            dataPoints: tempData,
                            dataCaption: '${(dataModel?.ActRPM ?? 0)} %',
                            chartLabel: 'Act RPM',
                            borderRadius: cornerRadius,
                            backgroundColor: const Color.fromARGB(255, 0, 0, 0),
                            gradientColors: const [
                              Color(0xFFFA0303),
                              Color(0xFFD36702),
                              Color(0xFFEB482C),
                            ],
                            captionTextStyle: const TextStyle(
                              fontSize: 38, // Adjust the font size as needed
                              fontWeight: FontWeight
                                  .bold, // Optional: Adjust the font weight as needed
                            ),
                            labelStyle: TextStyle(
                                fontSize:
                                    13), // Add the labelStyle parameter here
                          ),
                        ),
                      ),
                    ),
                  ),
                  UIHelper.horizontalSpaceVerySmall(),
                ],
              ),
            ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    flex: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(2.0),
                      child: Material(
                        shape:
                            CircleBorder(), // Use CircleBorder to make it round
                        color: (dataModel?.Run == 0)
                            ? Color.fromARGB(255, 156, 16,
                                6) // Set red background when reg3 is 0
                            : (dataModel?.Run == 1)
                                ? Colors
                                    .green // Set green background when reg3 is 1
                                : Color.fromARGB(255, 22, 24, 20),
                        elevation: 1.5,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Visibility(
                                visible: (dataModel?.Run ?? 0) != 0,
                                child: CustomLineChart(
                                  dataPoints: tempData,
                                  dataCaption: '${(dataModel?.Run ?? 0)}',
                                  chartLabel: 'Run',
                                  borderRadius: cornerRadius,
                                  backgroundColor: Color.fromARGB(255, 0, 0, 0),
                                  gradientColors: [
                                    const Color(0xFFFA0303),
                                    Color.fromARGB(255, 7, 245, 47),
                                    Color.fromARGB(255, 164, 247, 31),
                                  ],
                                  captionTextStyle: TextStyle(
                                    fontSize: 38, // Increase the font size here
                                    fontWeight: FontWeight.bold,
                                  ),
                                  labelStyle: TextStyle(
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              Visibility(
                                visible: (dataModel?.Run ?? 0) == 0,
                                child: Text(
                                  'OFF',
                                  style: TextStyle(
                                    fontSize:
                                        38, // Adjust the font size as needed
                                    fontWeight: FontWeight.bold,
                                    color: Colors
                                        .white, // Adjust the color as needed
                                  ),
                                ),
                              ),
                              Visibility(
                                visible: (dataModel?.Run ?? 0) == 1,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Text(
                                      'ON',
                                      style: TextStyle(
                                        fontSize:
                                            38, // Adjust the font size as needed
                                        fontWeight: FontWeight.bold,
                                        color: Colors
                                            .white, // Adjust the color as needed
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  UIHelper.horizontalSpaceVerySmall(),
                  // Expanded(
                  //   flex: 3,
                  //   child: Padding(
                  //     padding: const EdgeInsets.all(2.0),
                  //     child: Material(
                  //       shape:
                  //           CircleBorder(), // Use CircleBorder to make it round
                  //       color: (dataModel?.Trip == 0)
                  //           ? Color.fromARGB(255, 133, 120,
                  //               119) // Set red background when reg3 is 0
                  //           : (dataModel?.Trip == 1)
                  //               ? Colors
                  //                   .yellow // Set green background when reg3 is 1
                  //               : Color.fromARGB(255, 22, 24, 20),
                  //       elevation: 1.5,
                  //       child: FittedBox(
                  //         fit: BoxFit.scaleDown,
                  //         child: Stack(
                  //           alignment: Alignment.center,
                  //           children: [
                  //             Visibility(
                  //               visible: (dataModel?.Trip ?? 0) != 0,
                  //               child: CustomLineChart(
                  //                 dataPoints: tempData,
                  //                 dataCaption: '${(dataModel?.Trip ?? 0)}',
                  //                 chartLabel: 'Run',
                  //                 borderRadius: cornerRadius,
                  //                 backgroundColor: Color.fromARGB(255, 0, 0, 0),
                  //                 gradientColors: [
                  //                   const Color(0xFFFA0303),
                  //                   Color.fromARGB(255, 7, 245, 47),
                  //                   Color.fromARGB(255, 164, 247, 31),
                  //                 ],
                  //                 captionTextStyle: TextStyle(
                  //                   fontSize: 38, // Increase the font size here
                  //                   fontWeight: FontWeight.bold,
                  //                 ),
                  //                 labelStyle: TextStyle(
                  //                   fontSize: 13,
                  //                 ),
                  //               ),
                  //             ),
                  //             Visibility(
                  //               visible: (dataModel?.Trip ?? 0) == 0,
                  //               child: Text(
                  //                 'Trip',
                  //                 style: TextStyle(
                  //                   fontSize:
                  //                       38, // Adjust the font size as needed
                  //                   fontWeight: FontWeight.bold,
                  //                   color: Colors
                  //                       .white, // Adjust the color as needed
                  //                 ),
                  //               ),
                  //             ),
                  //             Visibility(
                  //               visible: (dataModel?.Trip ?? 0) == 1,
                  //               child: Container(
                  //                 decoration: BoxDecoration(
                  //                   color: Colors.yellow,
                  //                   shape: BoxShape.circle,
                  //                 ),
                  //                 child: Padding(
                  //                   padding: const EdgeInsets.all(16.0),
                  //                   child: Text(
                  //                     'Health',
                  //                     style: TextStyle(
                  //                       fontSize:
                  //                           30, // Adjust the font size as needed
                  //                       fontWeight: FontWeight.bold,
                  //                       color: Colors
                  //                           .white, // Adjust the color as needed
                  //                     ),
                  //                   ),
                  //                 ),
                  //               ),
                  //             ),
                  //           ],
                  //         ),
                  //       ),
                  //     ),
                  //   ),
                  // ),
                ],
              ),
            ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    flex: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(2.0),
                      child: Material(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(cornerRadius),
                        ),
                        color: Color.fromARGB(255, 16, 17, 15),
                        elevation: 1.5,
                        child: Padding(
                          padding: EdgeInsets.only(left: 100.0),
                          child: Stack(
                            children: [
                              // Your existing widget
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: CustomLineChart(
                                  dataPoints: tempData,
                                  dataCaption: '${(dataModel?.SetRPM ?? 0)} %',
                                  chartLabel: 'Set RPM',
                                  borderRadius: cornerRadius,
                                  backgroundColor:
                                      const Color.fromARGB(255, 0, 0, 0),
                                  gradientColors: const [
                                    Color(0xFFFA0303),
                                    Color(0xFFD36702),
                                    Color(0xFFEB482C),
                                  ],
                                  captionTextStyle: const TextStyle(
                                    fontSize:
                                        38, // Adjust the font size as needed
                                    fontWeight: FontWeight
                                        .bold, // Optional: Adjust the font weight as needed
                                  ),
                                  labelStyle: TextStyle(fontSize: 13),
                                ),
                              ),
                              // Edit icon at the top right corner
                              Positioned(
                                top: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: () {
                                    // Handle edit action here
                                    // Show your custom popup here
                                    TextEditingController setRPMController =
                                        TextEditingController(
                                            text: (dataModel?.SetRPM ?? 0)
                                                .toString());

                                    showDialog(
                                      context: context,
                                      builder: (BuildContext context) {
                                        String setRPMValue =
                                            ""; // Initialize an empty string

                                        return AlertDialog(
                                          title: Text("Edit"),
                                          content: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text("Change Set RPM Here"),
                                              SizedBox(height: 8),
                                              TextField(
                                                controller: setRPMController,
                                                keyboardType:
                                                    TextInputType.number,
                                                decoration: InputDecoration(
                                                  labelText: "Set RPM",
                                                  border: OutlineInputBorder(),
                                                ),
                                                onChanged: (value) {
                                                  // Update the setRPMValue variable when the TextField value changes
                                                  setRPMValue = value;
                                                },
                                              ),
                                            ],
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () {
                                                // Convert setRPMValue to an integer and then format it as hexadecimal
                                                int rpmValue =
                                                    int.tryParse(setRPMValue) ??
                                                        0;
                                                String hexValue =
                                                    rpmValue.toRadixString(16);

                                                // Ensure the hexadecimal value is padded with zeros if needed
                                                while (hexValue.length < 4) {
                                                  hexValue = '0$hexValue';
                                                }

                                                // Construct the command with the updated hexValue
                                                String command =
                                                    '\$IPCFG,<DEVCMD: MBCMD=01060064${hexValue}0000>';

                                                // Replace 'devices/esp01/get/sensor_dataC' with your desired topic
                                                String topic =
                                                    'devices/esp01/get/sensor_dataC';
                                                mqttService.publishMessage(
                                                    topic, command);

                                                // Close the dialog
                                                Navigator.of(context).pop();
                                              },
                                              child: Text("Save"),
                                            ),
                                            TextButton(
                                              onPressed: () {
                                                Navigator.of(context)
                                                    .pop(); // Close the popup
                                              },
                                              child: Text("Cancel"),
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                  },
                                  child: Icon(
                                    Icons.edit,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  UIHelper.horizontalSpaceVerySmall(),
                ],
              ),
            ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ButtonExpanded(
                    text: 'Start',

                    color: Colors.green, // Set the background color to green
                    icon: Icon(
                        Icons.play_arrow), // You can change the icon as needed
                    flex: 2,

                    borderRadius: cornerRadius,
                    enabled: ifConnected(),
                    height: 60.0,
                    onPressed: () {
                      // Check if MQTT client is connected before sending the command
                      if (ifConnected()) {
                        // Replace $IPCFG,<DEVCMD: MBCMD=01050064FF000000> with your desired command
                        String command =
                            "\$IPCFG,<DEVCMD: MBCMD=01050064FF000000>";
                        // Replace 'devices/esp01/get/sensor_dataC' with your desired topic
                        String topic = 'devices/esp01/get/sensor_dataC';
                        mqttService.publishMessage(topic, command);
                        // Publish the command to the MQTT topic
                      } else {
                        // MQTT client is not connected, handle accordingly
                        // You can show an error message or take appropriate action
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: Text("MQTT Not Connected"),
                              content: Text(
                                  "Please check your MQTT connection and try again."),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(context)
                                        .pop(); // Close the error dialog
                                  },
                                  child: Text("OK"),
                                ),
                              ],
                            );
                          },
                        );
                      }
                    },
                  ),
                  SizedBox(width: 16.0),
                  Container(
                      // Set the desired vertical spacing height
                      ),
                  ButtonExpanded(
                    text: 'Stop',
                    color: Color.fromARGB(
                        255, 248, 19, 2), // Set the background color to red
                    icon: Icon(Icons.stop), // You can change the icon as needed
                    flex: 2,
                    borderRadius: cornerRadius,
                    enabled: ifConnected(),
                    height: 60,

                    onPressed: () {
                      // Check if MQTT client is connected before sending the command
                      if (ifConnected()) {
                        // Replace $IPCFG,<DEVCMD: MBCMD=01050064FF000000> with your desired command
                        String command =
                            "\$IPCFG,<DEVCMD: MBCMD=01050065FF000000>";
                        // Replace 'devices/esp01/get/sensor_dataC' with your desired topic
                        String topic = 'devices/esp01/get/sensor_dataC';
                        mqttService.publishMessage(topic, command);
                        // Publish the command to the MQTT topic
                      } else {
                        // MQTT client is not connected, handle accordingly
                        // You can show an error message or take appropriate action
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: Text("MQTT Not Connected"),
                              content: Text(
                                  "Please check your MQTT connection and try again."),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(context)
                                        .pop(); // Close the error dialog
                                  },
                                  child: Text("OK"),
                                ),
                              ],
                            );
                          },
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildGraph(BuildContext context) {
    return SingleChildScrollView(
      child: SizedBox(
        height: MediaQuery.of(context).size.height,
        child: Column(
          children: [
            Expanded(
              child: Container(
                width: 270,
                padding: const EdgeInsets.all(8.0), // Adjust padding as needed
                color: Colors.green,
                // Set the background color as desired
                child: Center(
                  child: Text(
                    'Device 1 Modbus1',
                    // Add your content here
                    style: TextStyle(
                      fontSize: 20, // Adjust font size as needed
                      color: Colors.white, // Set text color as desired
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    flex: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(2.0),
                      child: Material(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(cornerRadius),
                        ),
                        color: Color.fromARGB(255, 16, 17, 15),
                        elevation: 1.5,
                        child: Stack(
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: CustomLineChart(
                                dataPoints: tempData,
                                dataCaption:
                                    '${(dataModel?.reg3 ?? 0).toInt()}(rpm)',
                                chartLabel: 'Turbine RPM',
                                borderRadius: cornerRadius,
                                backgroundColor:
                                    const Color.fromARGB(255, 0, 0, 0),
                                gradientColors: const [
                                  Color(0xFFFA0303),
                                  Color(0xFFD36702),
                                  Color(0xFFEB482C),
                                ],
                                captionTextStyle: const TextStyle(
                                  fontSize: 38,
                                  fontWeight: FontWeight.bold,
                                ),
                                labelStyle: TextStyle(
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 0, // Adjust the top position as needed
                              right: 0, // Adjust the right position as needed
                              child: GestureDetector(
                                onTap: () {
                                  // Handle the edit action here
                                },
                                child: Icon(
                                  Icons.edit,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  UIHelper.horizontalSpaceVerySmall(),
                  Expanded(
                    flex: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(2.0),
                      child: Material(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(cornerRadius),
                        ),
                        color: Color.fromARGB(255, 24, 26, 22),
                        elevation: 1.5,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: CustomLineChart(
                            dataPoints: humidData,
                            dataCaption: '${(dataModel?.reg2 ?? 0)} (V)',
                            chartLabel: 'Volts',
                            borderRadius: cornerRadius,
                            backgroundColor: Color.fromARGB(255, 0, 0, 0),
                            gradientColors: [
                              Color(0xFFFA0303),
                              Color(0xFFD36702),
                              Color(0xFFEB482C),
                            ],
                            captionTextStyle: TextStyle(
                              fontSize: 38, // Increase the font size here
                              fontWeight: FontWeight
                                  .bold, // Optional: Adjust the font weight as needed
                            ),
                            labelStyle: TextStyle(
                                fontSize:
                                    13), // Add the labelStyle parameter here
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    flex: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(2.0),
                      child: Material(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(cornerRadius),
                        ),
                        color: Color.fromARGB(255, 22, 24, 20),
                        elevation: 1.5,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: CustomLineChart(
                            dataPoints: tempData,
                            dataCaption: '${(dataModel?.reg3 ?? 0)} (I)',
                            chartLabel: 'Current',
                            borderRadius: cornerRadius,
                            backgroundColor: Color.fromARGB(255, 0, 0, 0),
                            gradientColors: [
                              const Color(0xFFFA0303),
                              Color.fromARGB(255, 7, 245, 47),
                              Color.fromARGB(255, 164, 247, 31),
                            ],
                            captionTextStyle: TextStyle(
                              fontSize: 38, // Increase the font size here
                              fontWeight: FontWeight
                                  .bold, // Optional: Adjust the font weight as needed
                            ),
                            labelStyle: TextStyle(
                                fontSize:
                                    13), // Add the labelStyle parameter here
                          ),
                        ),
                      ),
                    ),
                  ),
                  UIHelper.horizontalSpaceVerySmall(),
                  Expanded(
                    flex: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(2.0),
                      child: Material(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(cornerRadius),
                        ),
                        color: Color.fromARGB(255, 16, 17, 14),
                        elevation: 1.5,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: CustomLineChart(
                            dataPoints: humidData,
                            dataCaption: '${(dataModel?.reg4 ?? 0)} (Hz)',
                            chartLabel: 'Frequency',
                            borderRadius: cornerRadius,
                            backgroundColor: Color.fromARGB(255, 1, 1, 2),
                            gradientColors: [
                              Color.fromARGB(255, 2, 2, 2),
                              Color.fromARGB(255, 185, 250, 5),
                            ],
                            captionTextStyle: TextStyle(
                              fontSize: 38, // Increase the font size here
                              fontWeight: FontWeight
                                  .bold, // Optional: Adjust the font weight as needed
                            ),
                            labelStyle: TextStyle(
                                fontSize:
                                    13), // Add the labelStyle parameter here
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    flex: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(2.0),
                      child: Material(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(cornerRadius),
                        ),
                        color: Color.fromARGB(255, 14, 15, 13),
                        elevation: 1.5,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: CustomLineChart(
                            dataPoints: tempData,
                            dataCaption: '${(dataModel?.reg5 ?? 0)} (kw)',
                            chartLabel: 'Power',
                            borderRadius: cornerRadius,
                            backgroundColor: Color.fromARGB(255, 0, 0, 0),
                            gradientColors: [
                              Color.fromARGB(255, 200, 253, 8),
                              Color.fromARGB(255, 249, 253, 3),
                            ],
                            captionTextStyle: TextStyle(
                              fontSize: 38, // Increase the font size here
                              fontWeight: FontWeight
                                  .bold, // Optional: Adjust the font weight as needed
                            ),
                            labelStyle: TextStyle(
                                fontSize:
                                    13), // Add the labelStyle parameter here
                          ),
                        ),
                      ),
                    ),
                  ),
                  UIHelper.horizontalSpaceVerySmall(),
                  Expanded(
                    flex: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(2.0),
                      child: Material(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(cornerRadius),
                        ),
                        color: Color.fromARGB(255, 24, 24, 21),
                        elevation: 1.5,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: CustomLineChart(
                            dataPoints: humidData,
                            dataCaption:
                                (dataModel?.reg6 ?? 0).toString() + '(kgs/hr)',
                            chartLabel: 'Steam Flow',
                            borderRadius: cornerRadius,
                            backgroundColor: Color.fromARGB(255, 0, 0, 0),
                            gradientColors: [
                              Color.fromARGB(255, 3, 3, 3),
                              Color.fromARGB(255, 0, 0, 0),
                            ],
                            labelStyle: TextStyle(fontSize: 13),
                            captionTextStyle: TextStyle(
                              fontSize: 40, // Increase the font size here
                              fontWeight: FontWeight
                                  .bold, // Optional: Adjust the font weight as needed
                            ), // Provide captionTextStyle with the desired font size
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    flex: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(2.0),
                      child: Material(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(cornerRadius),
                        ),
                        color: Color.fromARGB(255, 22, 24, 21),
                        elevation: 1.5,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: CustomLineChart(
                            dataPoints: tempData,
                            dataCaption: '${(dataModel?.reg7 ?? 0)} (Kg/cm2)',
                            chartLabel: 'Inlet Steam Pressure - PT200',
                            borderRadius: cornerRadius,
                            backgroundColor: Color.fromARGB(255, 0, 0, 0),
                            gradientColors: [
                              Color.fromARGB(255, 29, 2, 2),
                              Color.fromARGB(255, 48, 6, 6),
                              Color.fromARGB(255, 37, 3, 3),
                            ],
                            captionTextStyle: TextStyle(
                              fontSize: 38, // Adjust the font size as needed
                              fontWeight: FontWeight
                                  .bold, // Optional: Adjust the font weight as needed
                            ),
                            labelStyle: TextStyle(
                                fontSize:
                                    13), // Add the labelStyle parameter here
                          ),
                        ),
                      ),
                    ),
                  ),
                  UIHelper.horizontalSpaceVerySmall(),
                  Expanded(
                    flex: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(2.0),
                      child: Material(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(cornerRadius),
                        ),
                        color: Color.fromARGB(255, 21, 22, 20),
                        elevation: 1.5,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: CustomLineChart(
                            dataPoints: humidData,
                            dataCaption: '${(dataModel?.reg8 ?? 0)} (kg/cm2)',
                            chartLabel: 'Exhaust Steam Pressure - PT202',
                            borderRadius: cornerRadius,
                            backgroundColor: Color.fromARGB(255, 1, 1, 2),
                            gradientColors: [
                              Color.fromARGB(255, 206, 5, 172),
                              Color.fromARGB(255, 12, 12, 11),
                            ],
                            captionTextStyle: TextStyle(
                              fontSize: 38, // Adjust the font size as needed
                              fontWeight: FontWeight
                                  .bold, // Optional: Adjust the font weight as needed
                            ),
                            labelStyle: TextStyle(
                                fontSize:
                                    13), // Add the labelStyle parameter here
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    flex: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(2.0),
                      child: Material(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(cornerRadius),
                        ),
                        color: Color.fromARGB(255, 22, 24, 21),
                        elevation: 1.5,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: CustomLineChart(
                            dataPoints: tempData,
                            dataCaption: '${(dataModel?.reg9 ?? 0)} (mm/s)',
                            chartLabel: 'HP Vibration - VS200',
                            borderRadius: cornerRadius,
                            backgroundColor: Color.fromARGB(255, 0, 0, 0),
                            gradientColors: [
                              Color.fromARGB(255, 29, 2, 2),
                              Color.fromARGB(255, 48, 6, 6),
                              Color.fromARGB(255, 37, 3, 3),
                            ],
                            captionTextStyle: TextStyle(
                              fontSize:
                                  38, // Adjust the initial font size as needed
                              fontWeight: FontWeight.bold,
                            ),
                            labelStyle: TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                    ),
                  ),
                  UIHelper.horizontalSpaceVerySmall(),
                  Expanded(
                    flex: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(2.0),
                      child: Material(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(cornerRadius),
                        ),
                        color: Color.fromARGB(255, 21, 22, 20),
                        elevation: 1.5,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: CustomLineChart(
                            dataPoints: humidData,
                            dataCaption: '${(dataModel?.reg10 ?? 0)} (°C)',
                            chartLabel: 'Inlet Steam Temperature - RTD200',
                            borderRadius: cornerRadius,
                            backgroundColor: Color.fromARGB(255, 1, 1, 2),
                            gradientColors: [
                              Color.fromARGB(255, 206, 5, 172),
                              Color.fromARGB(255, 12, 12, 11),
                            ],
                            captionTextStyle: TextStyle(
                              fontSize:
                                  38, // Adjust the initial font size as needed
                              fontWeight: FontWeight.bold,
                            ),
                            labelStyle: TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    flex: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(2.0),
                      child: Material(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(cornerRadius),
                        ),
                        color: Color.fromARGB(255, 16, 17, 15),
                        elevation: 1.5,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: CustomLineChart(
                            dataPoints: tempData,
                            dataCaption:
                                '${(dataModel?.reg11 ?? 0).toInt()}(°C)',
                            chartLabel: 'Exhaust  Steam Temprature - RTD200',
                            borderRadius: cornerRadius,
                            backgroundColor: const Color.fromARGB(255, 0, 0, 0),
                            gradientColors: const [
                              Color(0xFFFA0303),
                              Color(0xFFD36702),
                              Color(0xFFEB482C),
                            ],
                            captionTextStyle: const TextStyle(
                              fontSize: 38, // Adjust the font size as needed
                              fontWeight: FontWeight
                                  .bold, // Optional: Adjust the font weight as needed
                            ),
                            labelStyle: TextStyle(
                                fontSize:
                                    13), // Add the labelStyle parameter here
                          ),
                        ),
                      ),
                    ),
                  ),
                  UIHelper.horizontalSpaceVerySmall(),
                  Expanded(
                    flex: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(2.0),
                      child: Material(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(cornerRadius),
                        ),
                        color: Color.fromARGB(255, 24, 26, 22),
                        elevation: 1.5,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: CustomLineChart(
                            dataPoints: humidData,
                            dataCaption: '${(dataModel?.reg12 ?? 0)} (°C)',
                            chartLabel:
                                'Rotor Front Bearing Temprature - RTD600',
                            borderRadius: cornerRadius,
                            backgroundColor: Color.fromARGB(255, 0, 0, 0),
                            gradientColors: [
                              Color(0xFFFA0303),
                              Color(0xFFD36702),
                              Color(0xFFEB482C),
                            ],
                            captionTextStyle: TextStyle(
                              fontSize: 38, // Increase the font size here
                              fontWeight: FontWeight
                                  .bold, // Optional: Adjust the font weight as needed
                            ),
                            labelStyle: TextStyle(
                                fontSize:
                                    13), // Add the labelStyle parameter here
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    flex: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(2.0),
                      child: Material(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(cornerRadius),
                        ),
                        color: Color.fromARGB(255, 16, 17, 15),
                        elevation: 1.5,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: CustomLineChart(
                            dataPoints: tempData,
                            dataCaption: '${(dataModel?.reg13 ?? 0)} (°C)',
                            chartLabel:
                                'Rotor Rear Bearing Temprature - RTD601',
                            borderRadius: cornerRadius,
                            backgroundColor: const Color.fromARGB(255, 0, 0, 0),
                            gradientColors: const [
                              Color(0xFFFA0303),
                              Color(0xFFD36702),
                              Color(0xFFEB482C),
                            ],
                            captionTextStyle: const TextStyle(
                              fontSize: 38, // Adjust the font size as needed
                              fontWeight: FontWeight
                                  .bold, // Optional: Adjust the font weight as needed
                            ),
                            labelStyle: TextStyle(
                                fontSize:
                                    13), // Add the labelStyle parameter here
                          ),
                        ),
                      ),
                    ),
                  ),
                  UIHelper.horizontalSpaceVerySmall(),
                  Expanded(
                    flex: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(2.0),
                      child: Material(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(cornerRadius),
                        ),
                        color: Color.fromARGB(255, 24, 26, 22),
                        elevation: 1.5,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: CustomLineChart(
                            dataPoints: humidData,
                            dataCaption: '${(dataModel?.reg14 ?? 0)} (°C)',
                            chartLabel: 'IG DE Bearing Temprature - RTD602',
                            borderRadius: cornerRadius,
                            backgroundColor: Color.fromARGB(255, 0, 0, 0),
                            gradientColors: [
                              Color(0xFFFA0303),
                              Color(0xFFD36702),
                              Color(0xFFEB482C),
                            ],
                            captionTextStyle: TextStyle(
                              fontSize: 38, // Increase the font size here
                              fontWeight: FontWeight
                                  .bold, // Optional: Adjust the font weight as needed
                            ),
                            labelStyle: TextStyle(
                                fontSize:
                                    13), // Add the labelStyle parameter here
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    flex: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(2.0),
                      child: Material(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(cornerRadius),
                        ),
                        color: Color.fromARGB(255, 16, 17, 15),
                        elevation: 1.5,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: CustomLineChart(
                            dataPoints: tempData,
                            dataCaption: '${(dataModel?.reg15 ?? 0)} (°C)',
                            chartLabel: 'IG NDE Bearing Temprature - RTD603',
                            borderRadius: cornerRadius,
                            backgroundColor: const Color.fromARGB(255, 0, 0, 0),
                            gradientColors: const [
                              Color(0xFFFA0303),
                              Color(0xFFD36702),
                              Color(0xFFEB482C),
                            ],
                            captionTextStyle: const TextStyle(
                              fontSize: 38, // Adjust the font size as needed
                              fontWeight: FontWeight
                                  .bold, // Optional: Adjust the font weight as needed
                            ),
                            labelStyle: TextStyle(
                                fontSize:
                                    13), // Add the labelStyle parameter here
                          ),
                        ),
                      ),
                    ),
                  ),
                  UIHelper.horizontalSpaceVerySmall(),
                  Expanded(
                    flex: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(2.0),
                      child: Material(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(cornerRadius),
                        ),
                        color: Color.fromARGB(255, 24, 26, 22),
                        elevation: 1.5,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: CustomLineChart(
                            dataPoints: humidData,
                            dataCaption: '${(dataModel?.reg16 ?? 0)} (Tons/hr)',
                            chartLabel: 'Steam Totalizer',
                            borderRadius: cornerRadius,
                            backgroundColor: Color.fromARGB(255, 0, 0, 0),
                            gradientColors: [
                              Color(0xFFFA0303),
                              Color(0xFFD36702),
                              Color(0xFFEB482C),
                            ],
                            captionTextStyle: TextStyle(
                              fontSize: 38, // Increase the font size here
                              fontWeight: FontWeight
                                  .bold, // Optional: Adjust the font weight as needed
                            ),
                            labelStyle: TextStyle(
                                fontSize:
                                    13), // Add the labelStyle parameter here
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    flex: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(2.0),
                      child: Material(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(cornerRadius),
                        ),
                        color: Color.fromARGB(255, 16, 17, 15),
                        elevation: 1.5,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: CustomLineChart(
                            dataPoints: tempData,
                            dataCaption: '${(dataModel?.reg17 ?? 0)}',
                            chartLabel: 'Operation Hours',
                            borderRadius: cornerRadius,
                            backgroundColor: const Color.fromARGB(255, 0, 0, 0),
                            gradientColors: const [
                              Color(0xFFFA0303),
                              Color(0xFFD36702),
                              Color(0xFFEB482C),
                            ],
                            captionTextStyle: const TextStyle(
                              fontSize: 38, // Adjust the font size as needed
                              fontWeight: FontWeight
                                  .bold, // Optional: Adjust the font weight as needed
                            ),
                            labelStyle: TextStyle(
                                fontSize:
                                    13), // Add the labelStyle parameter here
                          ),
                        ),
                      ),
                    ),
                  ),
                  UIHelper.horizontalSpaceVerySmall(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// build panel for Port buttons
  Widget buildButtons(BuildContext context) {
    var theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ButtonExpanded(
              text: lang.ScreenHome.buttonPing,
              color: pingStatus ? theme.primaryColor : theme.buttonColor,
              icon: Icon(Icons.wifi_tethering),
              flex: 3,
              borderRadius: cornerRadius,
              enabled: ifConnected(),
              height: 60,
              onPressed: () {
                setState(() {
                  pingStatus = false;
                });
                mqttService.sendCommand(EspEventType.Ping, "");
              },
            ),
            UIHelper.horizontalSpaceVerySmall(),
            ButtonExpanded(
              text: lang.ScreenHome.buttonBeep,
              color: beepStatus ? theme.primaryColor : theme.buttonColor,
              icon: Icon(Icons.volume_up),
              flex: 3,
              borderRadius: cornerRadius,
              enabled: ifConnected(),
              height: 60,
              onPressed: () {
                setState(() {
                  beepStatus = false;
                });
                mqttService.sendCommand(EspEventType.Beep, "");
              },
            ),
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Port-1 button
            ButtonExpanded(
              text: 'Start',
              color: Colors.green, // Set the background color to green
              icon: Icon(Icons.play_arrow), // You can change the icon as needed
              flex: 3,
              borderRadius: cornerRadius,
              enabled: ifConnected(),
              height: 60,
              onPressed: () {
                // Add your onPressed logic here
              },
            ),

            // Port-2 button
            ButtonExpanded(
              text: port2Status
                  ? lang.ScreenHome.buttonPort2On
                  : lang.ScreenHome.buttonPort2Off,
              color: port2Status ? theme.primaryColor : theme.buttonColor,
              icon: Icon(Icons.filter_2),
              flex: 5,
              borderRadius: cornerRadius,
              enabled: ifConnected(),
              height: 60,
              onPressed: () {
                if (port2Status)
                  mqttService.sendCommand(EspEventType.ClosePort, "2");
                else
                  mqttService.sendCommand(EspEventType.OpenPort, "2");
              },
            ),
          ],
        ),
      ],
    );
  }

  /// build panel for event list

  void onTimerCallback(Timer? timer) {
    // print('==========>>> Timer Callback');
    connectMqttService();

    if (ifConnected()) {
      mqttService.sendCommand(EspEventType.GetData, "");
    }
  }

  /// on new mqtt settings event
  void onSettingsData(String newMqttBroker) {
    // reconnect with new mqtt settings
    mqttService.disconnect();
  }

  // process MQTT connection state
  void onMqttConnectionState(MqttConnectionState mqttConnectionState) {
    setState(() {
      eventLog.insert(
          0,
          LogEntry(
            logText:
                '${lang.ScreenHome.logConnectionStatus}: ${mqttConnectionState.toString().split('.')[1]}',
            logType: EspEventType.System,
            logTime: DateTime.now(),
          ));

      // maintain 30 items in the [eventLog] list
      if (eventLog.length > 30) {
        eventLog.removeLast();
      }
    });
  }

  /// process ESP Message data
  void onEspMessage(EspMessage espMessage) {
    print(
      '''=====> espMessageSubscription:
    ${espMessage.espEventType}
    ${espMessage.command}
    ${espMessage.parameter}''',
    );

    setState(() {
      // process sensor data
      if (espMessage.espEventType == EspEventType.GetData) {
        Map<String, dynamic>? sensorData;
        try {
          sensorData = jsonDecode(espMessage.command!);
        } catch (e) {
          sensorData = null;
        }
        if (sensorData == null) {
          var command = espMessage.command ?? "";
          print("data is => $command");
        } else {
          if (sensorData.containsKey('data')) {
            print("data is => ${sensorData['data']['modbus']}");
            dataModel = DataModel.fromJson(sensorData['data']['modbus'][0]);
          }
        }
        // stop processing further
        return;
      }

      if (espMessage.espEventType == EspEventType.Uptime) {
        deviceUptime = espMessage.parameter!;
      }

      if (espMessage.espEventType == EspEventType.Ping) {
        pingStatus = true;
      }

      if (espMessage.espEventType == EspEventType.Beep) {
        beepStatus = true;
      }

      // set port1 status
      if (espMessage.parameter == "1") {
        port1Status = (espMessage.espEventType == EspEventType.OpenPort);
      }

      // set port2 status
      if (espMessage.parameter == "2") {
        port2Status = (espMessage.espEventType == EspEventType.OpenPort);
      }

      // if 'Show Log' settings is not set, skip this log entry
      if (espMessage.espEventType == EspEventType.Log) {
        if (!PrefService.of(context).get<bool>(SettingsHelper.show_log)!)
          return;
      }

      // create an list item entry in the [eventLog] list
      eventLog.insert(
          0,
          LogEntry(
            logText: espMessage.command,
            logType: espMessage.espEventType,
            logTime: DateTime.now(),
          ));

      // maintain 30 items in the [eventLog] list
      if (eventLog.length > 30) {
        eventLog.removeLast();
      }
    });
  }

  // our parse duration function to process uptime data
  Duration parseDuration(String durationString) {
    int days = 0;
    int hours = 0;
    int minutes = 0;
    int seconds = 0;
    List<String> parts = durationString.split(':');

    // if this is a malformed string, return zero duration
    if (parts.length == 0 || parts.length > 4) {
      return Duration.zero;
    }

    days = int.parse(parts[parts.length - 4]);
    hours = int.parse(parts[parts.length - 3]);
    minutes = int.parse(parts[parts.length - 2]);
    seconds = int.parse(parts[parts.length - 1]);

    return Duration(
      days: days,
      hours: hours,
      minutes: minutes,
      seconds: seconds,
    );
  }
}

class DataModel {
  double? ActRPM;
  int? Run;
  int? Trip;
  double? SetRPM;
  double? reg1;
  double? reg2;
  double? reg3;
  double? reg4;
  double? reg5;
  double? reg6;
  double? reg7;
  double? reg8;
  double? reg9;
  double? reg10;
  double? reg11;
  double? reg12;
  double? reg13;
  double? reg14;
  double? reg15;
  double? reg16;
  double? reg17;

  DataModel({
    this.ActRPM,
    this.Run,
    this.Trip,
    this.SetRPM,
    this.reg1,
    this.reg2,
    this.reg3,
    this.reg4,
    this.reg5,
    this.reg6,
    this.reg7,
    this.reg8,
    this.reg9,
    this.reg10,
    this.reg11,
    this.reg12,
    this.reg13,
    this.reg14,
    this.reg15,
    this.reg16,
    this.reg17,
  });
  factory DataModel.fromJson(Map<String, dynamic> json) {
    return DataModel(
      ActRPM: json['ActRPM']?.toDouble(), // Parse ActRPM as int
      Run: json['Run']?.toInt(),
      Trip: json['Trip']?.toInt(),
      SetRPM: json['SetRPM']?.toDouble(),
      reg1: json['reg1']?.toDouble(),
      reg2: json['reg2']?.toDouble(),
      reg3: json['reg3']?.toDouble(),
      reg4: json['reg4']?.toDouble(),
      reg5: json['reg5']?.toDouble(),
      reg6: json['reg6']?.toDouble(),
      reg7: json['reg7']?.toDouble(),
      reg8: json['reg8']?.toDouble(),
      reg9: json['reg9']?.toDouble(),
      reg10: json['reg10']?.toDouble(),
      reg11: json['reg11']?.toDouble(),
      reg12: json['reg12']?.toDouble(),
      reg13: json['reg13']?.toDouble(),
      reg14: json['reg14']?.toDouble(),
      reg15: json['reg15']?.toDouble(),
      reg16: json['reg16']?.toDouble(),
      reg17: json['reg17']?.toDouble(),
    );
  }
}
