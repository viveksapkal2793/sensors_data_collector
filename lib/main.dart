import 'dart:async';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_data_collector/acc_gyro_data.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'accelerometer_data.dart';
import 'gyroscope_data.dart';
import 'plotting.dart';
import 'dart:convert';
import 'location.dart';
import 'package:battery_info/battery_info_plugin.dart';
import 'dart:io';
// import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:to_csv/to_csv.dart' as exportCSV;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sensors Demo',
      theme: ThemeData(
        primarySwatch: Colors.teal,
      ),
      home: const MyHomePage(title: 'Flutter Sensor Data Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, this.title}) : super(key: key);

  final String? title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<double>? _accelerometerValues;
  List<double>? _gyroscopeValues;
  var apistatus;
  double bandwidth = 0.0;
  var current;
  var voltage;
  var initial_consumption;
  var current_consumption;
  var total_consumption;
  List<StreamSubscription<dynamic>> _streamSubscriptions = [];
  int select_time = 1;
  List<AccelerometerData> _accelerometerData = [];
  List<GyroscopeData> _gyroscopeData = [];
  List<AccGyroData> _accGyroData = [];
  List<AccelerometerData> _accelerometerData_for_turning = [];
  List<GyroscopeData> _gyroscopeData_for_turning = [];
  List<location_data> locations = [];
  List<String> customEvents = [];
  String _currentDate = '';
  String _currentTime = '';
  String activity_name = 'Normal';
  String behaviour_name = 'Low Risk';
  String custom_event = 'Nothing';
  double acc_sampling = 0.0;
  double gyro_sampling = 0.0;
  AccelerometerEvent? _lastAccEvent;
  GyroscopeEvent? _lastGyroEvent;
  Position? _lastPosition;
  late Timer timer;
  bool _isCollectingData = false;
  Timer? _timer;
  Timer? _timer2;
  Timer? _dateTimeTimer;
  var intervalMs = 200;
  final file_name = TextEditingController();
  TextEditingController eventController = TextEditingController();
  final TextEditingController _intervalController = TextEditingController(text: '200');

  @override
  Widget build(BuildContext context) {
    final accelerometer =
        _accelerometerValues?.map((double v) => v.toStringAsFixed(1)).toList();
    final gyroscope =
        _gyroscopeValues?.map((double v) => v.toStringAsFixed(1)).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('RouteMinder Profiler'),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Date: $_currentDate',
                      style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    'Time: $_currentTime',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  RichText(
                    text: TextSpan(
                    text: 'Interval in Milisec : ',
                    style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                    fontSize: 12))),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: TextField(
                        controller: _intervalController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Interval (ms)',
                          
                          border: OutlineInputBorder(),
                        ),
                        onChanged: _updateIntervalMs,
                      ),
                    ),
                  )
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0), 
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  MaterialButton(
                    child: Text(
                      "Start",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500),
                    ),
                    onPressed: () async {

                      if (_isCollectingData) return; // Prevent multiple starts

                      await Geolocator.checkPermission();
                      await Geolocator.requestPermission();
                      _accelerometerData.clear();
                      _gyroscopeData.clear();
                      locations.clear();
                      _accGyroData.clear();
                      setState(() {
                        _isCollectingData = true;
                      });

                      _streamSubscriptions = [];

                      _streamSubscriptions.add(
                        accelerometerEvents.listen((AccelerometerEvent event) async {
                          setState(() {
                            _accelerometerData.add(AccelerometerData(
                                DateTime.now(),
                                <double>[event.x, event.y, event.z],
                                activity_name,
                                behaviour_name,
                                custom_event));
                          });
                        }),
                      );

                      _streamSubscriptions.add(
                        gyroscopeEvents.listen((GyroscopeEvent event) async {
                          setState(() {
                            _gyroscopeData.add(GyroscopeData(
                                DateTime.now(),
                                <double>[event.x, event.y, event.z],
                                activity_name,
                                behaviour_name,
                                custom_event));
                          });
                        }),
                      );

                      StreamSubscription gyroscopeSubscription = gyroscopeEvents.listen((GyroscopeEvent gyro_event) {
                        _lastGyroEvent = gyro_event;
                      });
                      _streamSubscriptions.add(gyroscopeSubscription);
                      
                      StreamSubscription accelerometerSubscription = accelerometerEvents.listen((AccelerometerEvent acc_event) {
                        _lastAccEvent = acc_event;
                      });
                      _streamSubscriptions.add(accelerometerSubscription);

                      StreamSubscription positionSubscription = Geolocator.getPositionStream(
                        locationSettings: LocationSettings(
                          accuracy: LocationAccuracy.high,
                          distanceFilter: 0, // Get updates as frequently as possible
                        ),
                      ).listen((Position position) {
                        _lastPosition = position;
                      });
                      _streamSubscriptions.add(positionSubscription);

                      // Start combined data collection using a timer
                      _timer = Timer.periodic(Duration(milliseconds: intervalMs), (timer) async {
                        if (!_isCollectingData) return;
                        if (_lastGyroEvent != null && _lastAccEvent != null && _lastPosition != null) {
                          setState(() {
                            _accGyroData.add(AccGyroData(
                              DateTime.now(),
                              <double>[_lastAccEvent!.x, _lastAccEvent!.y, _lastAccEvent!.z],
                              <double>[_lastGyroEvent!.x, _lastGyroEvent!.y, _lastGyroEvent!.z],
                              _lastPosition!.latitude,
                              _lastPosition!.longitude,
                              activity_name,
                              behaviour_name,
                              custom_event,
                            ));
                          });
                        setState(() {
                          locations.add(location_data(
                            DateTime.now(),
                            _lastPosition!.latitude,
                            _lastPosition!.longitude,
                            activity_name,
                            behaviour_name,
                            custom_event,
                          ));
                      });};
                      });

                      print(select_time);
                      timer =
                          Timer.periodic(Duration(seconds: select_time), (timer) {
                        // printing_all_data( );
                      });
                    },
                    color: Colors.teal,
                    minWidth: 10,
                    height: 25,
                  ),
                  SizedBox(
                    width: MediaQuery.of(context).size.width / 6,
                  ),
                  MaterialButton(
                    child: Text(
                      "Stop",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500),
                    ),
                    onPressed: () async {
                      
                      if (!_isCollectingData) return; // Prevent multiple stops
                      
                      // print("length: ${_accelerometerData.length}");
                      // print("length: ${_gyroscopeData.length}");
                      
                      await collectAndSaveData();
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Data saved to CSV')),
                      );
                      
                      await sendDataToBackend(_accGyroData); // Send data to backend
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Data sent to backend')),
                      );

                      setState(() {
                        _isCollectingData = false;
                      });

                      _streamSubscriptions.forEach((subscription) {
                        subscription.pause();
                      });
                      _timer?.cancel();
                      _timer2?.cancel();
                      // _accelerometerData.clear();
                      // _gyroscopeData.clear();
                      // timer.cancel();
                    },
                    color: Colors.red,
                    minWidth: 10,
                    height: 25,
                  ),
                  SizedBox(
                    width: MediaQuery.of(context).size.width / 6,
                  ),
                  MaterialButton(
                    child: Text(
                      "Plot",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500),
                    ),
                    onPressed: () {
                      _plotData();
                      // _accelerometerData.clear();
                      // _gyroscopeData.clear();
                      },
                    color: const Color.fromARGB(255, 54, 117, 244),
                    minWidth: 10,
                    height: 25,
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.only(
                  left: MediaQuery.of(context).size.width / 40,
                  right: MediaQuery.of(context).size.width / 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  RichText(
                      text: TextSpan(
                          text: 'Activity Type',
                          style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Colors.black,
                              fontSize: 12))),
                  MaterialButton(
                    onPressed: () {
                      setState(() {
                        activity_name = 'Normal';
                      });
                    },
                    minWidth: 10,
                    height: 30,
                    child: Text(
                      "Normal",
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    color: const Color.fromARGB(255, 0, 52, 150),
                  ),
                  MaterialButton(
                    onPressed: () {
                      setState(() {
                        activity_name = 'Acceleration';
                      });
                    },
                    minWidth: 10,
                    height: 30,
                    child: Text(
                      "Acceleration",
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    color: const Color.fromARGB(255, 27, 150, 0),
                  ),
                  MaterialButton(
                    onPressed: () {
                      setState(() {
                        activity_name = 'Break';
                      });
                    },
                    minWidth: 10,
                    height: 30,
                    child: Text(
                      "Break",
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    color: const Color.fromARGB(255, 150, 0, 57),
                  ),
                  MaterialButton(
                    onPressed: () {
                      setState(() {
                        activity_name = 'Turn';
                      });
                    },
                    minWidth: 10,
                    height: 30,
                    child: Text(
                      "Turn",
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    color: const Color.fromARGB(255, 194, 102, 44),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.only(
                  left: MediaQuery.of(context).size.width / 40,
                  right: MediaQuery.of(context).size.width / 40,
                  bottom: MediaQuery.of(context).size.width / 60),
              child: RichText(
                text: TextSpan(
                  text: 'Activity: ',
                  style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
                      fontSize: 12),
                  children: <TextSpan>[
                    TextSpan(
                      text: activity_name,
                      style: TextStyle(
                          fontWeight: FontWeight.w300,
                          color: Colors.black,
                          fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(
                  left: MediaQuery.of(context).size.width / 40,
                  right: MediaQuery.of(context).size.width / 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  RichText(
                      text: TextSpan(
                          text: 'Behaviour Type',
                          style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Colors.black,
                              fontSize: 12))),
                  MaterialButton(
                    onPressed: () {
                      setState(() {
                        behaviour_name = 'Low Risk';
                      });
                    },
                    minWidth: 10,
                    height: 30,
                    child: Text(
                      "Low Risk",
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    color: const Color.fromARGB(255, 25, 200, 36),
                  ),
                  MaterialButton(
                    onPressed: () {
                      setState(() {
                        behaviour_name = 'Moderate Risk';
                      });
                    },
                    minWidth: 10,
                    height: 30,
                    child: Text(
                      "Moderate Risk",
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    color: const Color.fromARGB(255, 199, 183, 35),
                  ),
                  MaterialButton(
                    onPressed: () {
                      setState(() {
                        behaviour_name = 'High Risk';
                      });
                    },
                    minWidth: 10,
                    height: 30,
                    child: Text(
                      "High Risk",
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    color: const Color.fromARGB(255, 216, 38, 11),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.only(
                  left: MediaQuery.of(context).size.width / 40,
                  right: MediaQuery.of(context).size.width / 40,
                  bottom: MediaQuery.of(context).size.width / 60),
              child: RichText(
                text: TextSpan(
                  text: 'Behaviour: ',
                  style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
                      fontSize: 12),
                  children: <TextSpan>[
                    TextSpan(
                      text: behaviour_name,
                      style: TextStyle(
                          fontWeight: FontWeight.w300,
                          color: Colors.black,
                          fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(
                  left: MediaQuery.of(context).size.width / 40,
                  right: MediaQuery.of(context).size.width / 40),
              child: Column(
                children: [
                  Row(
                    children:[
                      RichText(
                          text: TextSpan(
                              text: 'Custom Events: ',
                              style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black,
                                  fontSize: 12))),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.all(8.0),
                            child: TextField(
                              controller: eventController,
                              decoration: InputDecoration(
                                labelText: 'Add Custom Event',
                                suffixIcon: IconButton(
                                  icon: Icon(Icons.add),
                                  onPressed: _addCustomEvent,
                                ),
                              ),
                            ),
                          ),
                      ),
                    ]
                  ),
                  Wrap(
                    // mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    spacing: 8.0,
                    runSpacing: 4.0,
                    children: [
                      MaterialButton(
                        onPressed: () {
                          setState(() {
                            custom_event = 'Nothing';
                          });
                        },
                        minWidth: 10,
                        height: 30,
                        child: Text(
                          "Nothing",
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                        color: const Color.fromARGB(255, 39, 123, 202),
                      ),
                      ...customEvents.map((event) => MaterialButton(
                            onPressed: () {
                              setState(() {
                                custom_event = event;
                              });
                            },
                            minWidth: 10,
                            height: 30,
                            color: const Color.fromARGB(255, 39, 139, 202),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  event,
                                  style: TextStyle(color: Colors.white, fontSize: 12),
                                ),
                                SizedBox(width: 4),
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      customEvents.remove(event);
                                      _saveCustomEvents();
                                    });
                                  },
                                  child: Icon(
                                    Icons.close,
                                    color: Colors.black,
                                    size: 12,
                                  ),
                                ),
                              ],
                            ),
                        ),
                      ),                
                    ],
                  ),
                ]
              )
            ),
            Padding(
              padding: EdgeInsets.only(
                  left: MediaQuery.of(context).size.width / 40,
                  right: MediaQuery.of(context).size.width / 40,
                  bottom: MediaQuery.of(context).size.width / 60),
              child: RichText(
                text: TextSpan(
                  text: 'Custom Event: ',
                  style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
                      fontSize: 12),
                  children: <TextSpan>[
                    TextSpan(
                      text: custom_event,
                      style: TextStyle(
                          fontWeight: FontWeight.w300,
                          color: Colors.black,
                          fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(
                  left: MediaQuery.of(context).size.width / 40,
                  right: MediaQuery.of(context).size.width / 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  MaterialButton(
                    onPressed: () {
                      checkAccelerometerSamplingRate();
                      checkgyroSamplingRate();
                    },
                    height: 30,
                    minWidth: 10,
                    child: Text("Sampling",
                        style: TextStyle(color: Colors.white, fontSize: 12)),
                    color: Colors.teal,
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      RichText(
                        text: TextSpan(
                          text: 'Acc Sampling: ',
                          style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Colors.black,
                              fontSize: 12),
                          children: <TextSpan>[
                            TextSpan(
                              text: '$acc_sampling',
                              style: TextStyle(
                                  fontWeight: FontWeight.w300,
                                  color: Colors.black,
                                  fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      RichText(
                        text: TextSpan(
                          text: 'Gyro Sampling: ',
                          style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Colors.black,
                              fontSize: 12),
                          children: <TextSpan>[
                            TextSpan(
                              text: '$gyro_sampling',
                              style: TextStyle(
                                  fontWeight: FontWeight.w300,
                                  color: Colors.black,
                                  fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.only(
                  top: MediaQuery.of(context).size.width / 20,
                  left: MediaQuery.of(context).size.width / 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  RichText(
                    text: TextSpan(
                      text: 'Accelerometer: ',
                      style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.black,
                          fontSize: 12),
                      children: <TextSpan>[
                        TextSpan(
                          text: '$accelerometer',
                          style: TextStyle(
                              fontWeight: FontWeight.w300,
                              color: Colors.black,
                              fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  RichText(
                    text: TextSpan(
                      text: 'Gyroscope: ',
                      style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.black,
                          fontSize: 12),
                      children: <TextSpan>[
                        TextSpan(
                          text: '$gyroscope',
                          style: TextStyle(
                              fontWeight: FontWeight.w300,
                              color: Colors.black,
                              fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.only(
                  top: MediaQuery.of(context).size.width / 20,
                  left: MediaQuery.of(context).size.width / 40,
                  bottom: MediaQuery.of(context).size.width / 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  RichText(
                    text: TextSpan(
                      text: 'Length Accelerometer: ',
                      style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.black,
                          fontSize: 12),
                      children: <TextSpan>[
                        TextSpan(
                          text: '${_accelerometerData.length}',
                          style: TextStyle(
                              fontWeight: FontWeight.w300,
                              color: Colors.black,
                              fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  RichText(
                    text: TextSpan(
                      text: 'Length Gyro: ',
                      style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.black,
                          fontSize: 12),
                      children: <TextSpan>[
                        TextSpan(
                          text: '${_gyroscopeData.length}',
                          style: TextStyle(
                              fontWeight: FontWeight.w300,
                              color: Colors.black,
                              fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.only(
                  top: MediaQuery.of(context).size.width / 40,
                  left: MediaQuery.of(context).size.width / 40,
                  right: MediaQuery.of(context).size.width / 40,
                  bottom: MediaQuery.of(context).size.width / 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(
                    width: MediaQuery.of(context).size.width / 2.5,
                    child: TextFormField(
                      onChanged: (value) {
                        select_time = int.parse(value);
                      },
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(1),
                      ],
                      enableInteractiveSelection: false,
                      style: TextStyle(color: Color(0xff335F5E)),
                      textAlign: TextAlign.left,
                      decoration: InputDecoration(
                          hintText: 'Time',
                          hintStyle: TextStyle(
                              fontWeight: FontWeight.w400,
                              color: Colors.black,
                              fontSize: 12)),
                      validator: (firstname) =>
                          firstname != null && firstname.length < 1
                              ? 'First name cannot be empty'
                              : null,
                    ),
                  ),
                  SizedBox(
                    width: MediaQuery.of(context).size.width / 2.5,
                    child: TextFormField(
                      onChanged: (value) {},
                      controller: file_name,
                      keyboardType: TextInputType.name,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(20),
                      ],
                      enableInteractiveSelection: false,
                      style: TextStyle(color: Color(0xff335F5E)),
                      textAlign: TextAlign.left,
                      decoration: InputDecoration(
                          hintText: 'filename',
                          hintStyle: TextStyle(
                              fontWeight: FontWeight.w400,
                              color: Colors.black,
                              fontSize: 12)),
                      validator: (firstname) =>
                          firstname != null && firstname.length < 1
                              ? 'First name cannot be empty'
                              : null,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.only(
                  top: MediaQuery.of(context).size.width / 40,
                  left: MediaQuery.of(context).size.width / 40,
                  right: MediaQuery.of(context).size.width / 40,
                  bottom: MediaQuery.of(context).size.width / 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  MaterialButton(
                    onPressed: () async {
                      current = (await BatteryInfoPlugin().androidBatteryInfo)
                          ?.currentNow;
                      voltage = (await BatteryInfoPlugin().androidBatteryInfo)
                          ?.voltage;
                      setState(() {
                        initial_consumption =
                            (voltage / 1000) * (current / 1000) * select_time;
                      });
                    },
                    minWidth: 10,
                    height: 30,
                    child: Text(
                      "Initial Energy",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500),
                    ),
                    color: Colors.teal,
                  ),
                  RichText(
                    textAlign: TextAlign.end,
                    text: TextSpan(
                      text: 'Initial Energy in $select_time Sec\n',
                      style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.black,
                          fontSize: 12),
                      children: <TextSpan>[
                        TextSpan(
                          text: '$initial_consumption Joules',
                          style: TextStyle(
                              fontWeight: FontWeight.w300,
                              color: Colors.black,
                              fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.only(
                  top: MediaQuery.of(context).size.width / 20,
                  left: MediaQuery.of(context).size.width / 40,
                  bottom: MediaQuery.of(context).size.width / 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  RichText(
                    text: TextSpan(
                      text: 'Energy Consuming in $select_time: ',
                      style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.black,
                          fontSize: 12),
                      children: <TextSpan>[
                        TextSpan(
                          text: '$total_consumption Joules',
                          style: TextStyle(
                              fontWeight: FontWeight.w300,
                              color: Colors.black,
                              fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  RichText(
                    text: TextSpan(
                      text: 'Bandwidth: ',
                      style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.black,
                          fontSize: 12),
                      children: <TextSpan>[
                        TextSpan(
                          text: '$bandwidth Mbps',
                          style: TextStyle(
                              fontWeight: FontWeight.w300,
                              color: Colors.black,
                              fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.only(
                  left: MediaQuery.of(context).size.width / 40,
                  bottom: MediaQuery.of(context).size.width / 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  RichText(
                    text: TextSpan(
                      text: 'Current: ',
                      style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.black,
                          fontSize: 12),
                      children: <TextSpan>[
                        TextSpan(
                          text: '$current',
                          style: TextStyle(
                              fontWeight: FontWeight.w300,
                              color: Colors.black,
                              fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  RichText(
                    text: TextSpan(
                      text: 'Voltage: ',
                      style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.black,
                          fontSize: 12),
                      children: <TextSpan>[
                        TextSpan(
                          text: '$voltage',
                          style: TextStyle(
                              fontWeight: FontWeight.w300,
                              color: Colors.black,
                              fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.only(
                  left: MediaQuery.of(context).size.width / 40,
                  bottom: MediaQuery.of(context).size.width / 40),
              child: RichText(
                text: TextSpan(
                  text: 'Api Status: ',
                  style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
                      fontSize: 12),
                  children: <TextSpan>[
                    TextSpan(
                      text: '$apistatus',
                      style: TextStyle(
                          fontWeight: FontWeight.w300,
                          color: Colors.black,
                          fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer2?.cancel();  
    _dateTimeTimer?.cancel();
    _intervalController.dispose();
    super.dispose();
    for (final subscription in _streamSubscriptions) {
      subscription.cancel();
    }
  }

  @override
  void initState() {
    super.initState();
    _loadCustomEvents();
    _startDateTimeTimer();

    // _timer = Timer.periodic(Duration(minutes: 5), (timer) {
    //   collectAndSaveData();
    // });

    _streamSubscriptions.add(
      accelerometerEvents.listen((AccelerometerEvent event) {
        _accelerometerValues = <double>[event.x, event.y, event.z];
      }),
    );
    _streamSubscriptions.add(
      gyroscopeEvents.listen((GyroscopeEvent event) {
        _gyroscopeValues = <double>[event.x, event.y, event.z];
      }),
    );
  }

  Future<void> saveDataToCsv(
      List<Map<String, dynamic>> accelerometerData,
      List<Map<String, dynamic>> gyroscopeData,
      List<Map<String, dynamic>> accgyrodata,
      List<Map<String, dynamic>> accelerometerDataForTurning,
      List<Map<String, dynamic>> gyroscopeDataForTurning,
      List<Map<String, dynamic>> gpsData) async {
    // final directory = await getApplicationDocumentsDirectory();
    final directory = Directory('/storage/emulated/0/Download');
    if (!await directory.exists()) {
      print("Error: Unable to access external storage directory.");
      return;
    }
    final now = DateTime.now();
    final formattedDate =
        "${now.year}-${now.month}-${now.day}_${now.hour}-${now.minute}-${now.second}-${now.millisecond}";

    // Function to save a single type of data to a CSV file
    Future<void> saveSingleCsv(String type, List<List<dynamic>> rows) async {
      String csv = const ListToCsvConverter().convert(rows);
      final path = "${directory.path}/${type}_data_$formattedDate.csv";
      final file = File(path);
      await file.writeAsString(csv);
    }

    // Prepare and save accelerometer and gyroscope combined data
    List<List<dynamic>> accgyroRows = [
      [
        "Date",
        "Acc_X",
        "Acc_Y",
        "Acc_Z",
        "Gyro_X",
        "Gyro_Y",
        "Gyro_Z",
        "Latitude",
        "Longitude",
        "Activity Name",
        "Behaviour Name",
        "Custom Event"
      ]
    ];
    for (var data in accgyrodata) {
      var acc_values = data['Accvalue'] as List<dynamic>;
      var gyro_values = data['Gyrovalue'] as List<dynamic>;
      accgyroRows.add([
        data['date'],
        acc_values[0],
        acc_values[1],
        acc_values[2],
        gyro_values[0],
        gyro_values[1],
        gyro_values[2],
        data['lat'],
        data['long'], 
        data['activity_name'],
        data['behaviour_name'],
        data['custom_event']
      ]);
    }
    await saveSingleCsv("acc_gyro", accgyroRows);

    // Prepare and save gyroscope data
    List<List<dynamic>> accelerometerRows = [
      [
        "Type",
        "Date",
        "X",
        "Y",
        "Z",
        "Activity Name",
        "Behaviour Name",
        "Custom Event"
      ]
    ];
    for (var data in accelerometerData) {
      var values = data['value'] as List<dynamic>;
      accelerometerRows.add([
        "Acclerometer",
        data['date'],
        values[0],
        values[1],
        values[2],
        data['activity_name'],
        data['behaviour_name'],
        data['custom_event']
      ]);
    }
    await saveSingleCsv("acclerometer", accelerometerRows);

    // Prepare and save gyroscope data
    List<List<dynamic>> gyroscopeRows = [
      [
        "Type",
        "Date",
        "X",
        "Y",
        "Z",
        "Activity Name",
        "Behaviour Name",
        "Custom Event"
      ]
    ];
    for (var data in gyroscopeData) {
      var values = data['value'] as List<dynamic>;
      gyroscopeRows.add([
        "Gyroscope",
        data['date'],
        values[0],
        values[1],
        values[2],
        data['activity_name'],
        data['behaviour_name'],
        data['custom_event']
      ]);
    }
    await saveSingleCsv("gyroscope", gyroscopeRows);

    // // Prepare and save accelerometer data for turning
    // List<List<dynamic>> accelerometerTurningRows = [
    //   ["Type", "X", "Y", "Z", "Activity Name", "Date"]
    // ];
    // for (var data in accelerometerDataForTurning) {
    //   var values = data['value'] as List<dynamic>;
    //   accelerometerTurningRows.add([
    //     "AccelerometerTurning",
    //     values[0],
    //     values[1],
    //     values[2],
    //     data['activity_name'],
    //     data['date']
    //   ]);
    // }
    // await saveSingleCsv("accelerometer_turning", accelerometerTurningRows);

    // // Prepare and save gyroscope data for turning
    // List<List<dynamic>> gyroscopeTurningRows = [
    //   ["Type", "X", "Y", "Z", "Activity Name", "Date"]
    // ];
    // for (var data in gyroscopeDataForTurning) {
    //   var values = data['value'] as List<dynamic>;
    //   gyroscopeTurningRows.add([
    //     "GyroscopeTurning",
    //     values[0],
    //     values[1],
    //     values[2],
    //     data['activity_name'],
    //     data['date']
    //   ]);
    // }
    // await saveSingleCsv("gyroscope_turning", gyroscopeTurningRows);

    // Prepare and save GPS data
    List<List<dynamic>> gpsRows = [
      [
        "Type",
        "Date",
        "Latitude",
        "Longitude",
        "Altitude",
        "Activity Name",
        "Behaviour Name",
        "Custom Event"
      ]
    ];
    for (var data in gpsData) {
      gpsRows.add([
        "GPS",
        data['date'],
        data['lat'],
        data['long'],
        data['altitude'] ?? '',
        data['activity_name'],
        data['behaviour_name'],
        data['custom_event']
      ]);
    }
    // await saveSingleCsv("gps", gpsRows);
    // } else {
    //   print("Storage permission denied");
    // }
  }

  Future<void> collectAndSaveData() async {
    List<Map<String, dynamic>> getAccelerometerJsonData() {
      return _accelerometerData
          .map<Map<String, dynamic>>((data) => data.toJson())
          .toList();
    }

    List<Map<String, dynamic>> getGyroscopeJsonData() {
      return _gyroscopeData
          .map<Map<String, dynamic>>((data) => data.toJson())
          .toList();
    }
    
    List<Map<String, dynamic>> getAccGyroJsonData() {
      return _accGyroData
          .map<Map<String, dynamic>>((data) => data.toJson())
          .toList();
    }

    List<Map<String, dynamic>> getAccelerometerJsonData_or_turning() {
      return _accelerometerData_for_turning
          .map<Map<String, dynamic>>((data) => data.toJson())
          .toList();
    }

    List<Map<String, dynamic>> getGyroscopeJsonData_for_turning() {
      return _gyroscopeData_for_turning
          .map<Map<String, dynamic>>((data) => data.toJson())
          .toList();
    }

    // print("locations: $locations");

    final gpsData = locations.map((data) => data.toJson()).toList();
    final accelerometerValues = getAccelerometerJsonData();
    final gyroscopeValues = getGyroscopeJsonData();
    final accGyroValues = getAccGyroJsonData();
    final accelerometerValues_for_turning = getAccelerometerJsonData_or_turning();
    final gyroscopeValues_for_turning = getGyroscopeJsonData_for_turning();

    // // Debug: Print the collected data to verify
    // print("Accelerometer Data: $accelerometerValues");
    // print("Gyroscope Data: $gyroscopeValues");
    // print("AccGyro Data: $accGyroValues");
    // print("Accelerometer Data for Turning: $accelerometerValues_for_turning");
    // print("Gyroscope Data for Turning: $gyroscopeValues_for_turning");
    // print("GPS Data: $gpsData");

    await saveDataToCsv(
      accelerometerValues,
      gyroscopeValues,
      accGyroValues,
      accelerometerValues_for_turning,
      gyroscopeValues_for_turning,      
      gpsData,
    );
  }

  Future<void> sendDataToBackend(List<AccGyroData> accgyrodata) async {
    final url = Uri.parse('http://10.0.2.2:8000/sensors_app/receive-data/'); // Replace with your Django backend URL
    final headers = {'Content-Type': 'application/json'};
    
    List<Map<String, dynamic>> getAccGyroJsonData() {
      return _accGyroData
          .map<Map<String, dynamic>>((data) => data.toJson())
          .toList();
    }
    final accGyroValues = getAccGyroJsonData();
    print("accgyrodata: $accGyroValues");
    
    // final body = jsonEncode({'data': accgyrodata.map((data) => data.toJson()).toList()});
    final body = jsonEncode({'data': accGyroValues});

    try {
      final response = await http.post(url, headers: headers, body: body);
      if (response.statusCode == 200) {
        print('Data sent successfully');
      } else {
        print('Failed to send data: ${response.statusCode}');
      }
    } catch (e) {
      print('Error sending data: $e');
    }
  }

  // printing_all_data( ) async {

  //   try {
  //     final url = Uri.parse('http://3.110.222.52:8000/print_data');
  //     List<Map<String, dynamic>> getAccelerometerJsonData() {
  //       return _accelerometerData
  //           .map<Map<String, dynamic>>((data) => data.toJson())
  //           .toList();
  //     }

  //     List<Map<String, dynamic>> getGyroscopeJsonData() {
  //       return  _gyroscopeData.map<Map<String, dynamic>>((data) => data.toJson())
  //           .toList();}
  //     List<Map<String, dynamic>> getAccelerometerJsonData_or_turning() {
  //       return _accelerometerData_for_turning
  //           .map<Map<String, dynamic>>((data) => data.toJson())
  //           .toList();
  //     }
  //     List<Map<String, dynamic>> getGyroscopeJsonData_for_turning() {
  //       return  _gyroscopeData_for_turning.map<Map<String, dynamic>>((data) => data.toJson())
  //           .toList();}
  //     final gpsData = locations.map((data) => data.toJson()).toList();
  //     final accelerometerValues_for_turning = getAccelerometerJsonData_or_turning();
  //     final gyroscopeValues_for_turning  = getGyroscopeJsonData_for_turning();
  //     final accelerometerValues = getAccelerometerJsonData();
  //     final gyroscopeValues = getGyroscopeJsonData();
  //     var start_time=DateTime.now();
  //     current=(await BatteryInfoPlugin().androidBatteryInfo)?.currentNow;
  //     voltage=(await BatteryInfoPlugin().androidBatteryInfo)?.voltage;

  //     current_consumption=(voltage/1000)*(current/1000)*select_time;
  //     // print(current_consumption-initial_consumption);
  //     total_consumption=current_consumption-initial_consumption;
  //     var batt=(await BatteryInfoPlugin().androidBatteryInfo)?.batteryLevel;

  //     final requestBody = {
  //       'fname':file_name.text.trim(),
  //       'location':gpsData,
  //       'acc': accelerometerValues ,
  //       'gyro': gyroscopeValues,
  //       'acc_turning':accelerometerValues_for_turning,
  //       'gyro_turning':gyroscopeValues_for_turning,
  //       'start_time':start_time.toIso8601String(),
  //       'energy_consumption':total_consumption,
  //       'battery_percentage':batt
  //     };

  //     final response = await http.post(
  //       url,
  //       body: json.encode(requestBody),
  //       headers: {'Content-Type': 'application/json'},
  //     );
  //     apistatus=response.statusCode;

  //     if (response.statusCode == 200) {
  //       final requestBodyJson = json.encode(requestBody);
  //       final requestBodySize = utf8.encode(requestBodyJson).length;
  //       print('Request body size: $requestBodySize bytes');

  //       // Save data to CSV file
  //       // await saveDataToCsv(requestBody);

  //       final responseJson = await json.decode(response.body);
  //       var endTime = DateTime.parse(responseJson);

  //       var timeDifference = endTime.difference(start_time);
  //       print('Time difference: ${timeDifference.inMilliseconds} ms');

  //       var bandwidthMbps = (requestBodySize * 8 / 1000000) / timeDifference.inSeconds;

  //       bandwidth=bandwidthMbps;

  //       var othersnackbar = SnackBar(
  //         content: Text('Data Sent Successfully'),
  //         backgroundColor: Color(0xff335F5E),
  //         shape: OutlineInputBorder(borderRadius: BorderRadius.circular(1)),
  //         duration: Duration(milliseconds: 2000),
  //         behavior: SnackBarBehavior.floating,
  //       );
  //       setState(() {
  //         ScaffoldMessenger.of(context).showSnackBar(othersnackbar);
  //       });
  //     } else {

  //       var othersnackbar = SnackBar(
  //         content: Text('Failed to send data. Error: ${response.statusCode}'),
  //         backgroundColor: Color(0xff335F5E),
  //         shape: OutlineInputBorder(borderRadius: BorderRadius.circular(1)),
  //         duration: Duration(milliseconds: 2000),
  //         behavior: SnackBarBehavior.floating,
  //       );
  //       setState(() {
  //         ScaffoldMessenger.of(context).showSnackBar(othersnackbar);
  //       });
  //     }
  //     _accelerometerData.clear();
  //     _gyroscopeData.clear();
  //   } on Exception catch (e) {
  //     var othersnackbar = SnackBar(
  //       content: Text('$e'),
  //       backgroundColor: Color(0xff335F5E),
  //       shape: OutlineInputBorder(borderRadius: BorderRadius.circular(1)),
  //       duration: Duration(milliseconds: 2000),
  //       behavior: SnackBarBehavior.floating,
  //     );
  //     setState(() {
  //       ScaffoldMessenger.of(context).showSnackBar(othersnackbar);
  //     });

  //   }

  //  // print("Current: ${(await BatteryInfoPlugin().androidBatteryInfo)?.currentNow}");
  // //  print("Voltage: ${(await BatteryInfoPlugin().androidBatteryInfo)?.voltage}");

  // }

  void checkAccelerometerSamplingRate() {
    int eventCount = 0;
    final startTime = DateTime.now();

    StreamSubscription<AccelerometerEvent>? subscription;

    subscription = accelerometerEvents.listen((AccelerometerEvent event) {
      eventCount++;

      final currentTime = DateTime.now();
      final elapsed = currentTime.difference(startTime).inMilliseconds;

      if (elapsed >= 1000) {
        final samplingRate =
            eventCount / (elapsed / 1000); // Divide by 1000 to get rate in Hz
        setState(() {
          acc_sampling = samplingRate;
        });
        print('Accelerometer Sampling Rate: $samplingRate Hz');
        subscription?.cancel();
      }
    });
  }

  void checkgyroSamplingRate() {
    int eventCount = 0;
    final startTime = DateTime.now();

    StreamSubscription<GyroscopeEvent>? subscription;

    subscription = gyroscopeEvents.listen((GyroscopeEvent event) {
      eventCount++;

      final currentTime = DateTime.now();
      final elapsed = currentTime.difference(startTime).inMilliseconds;

      if (elapsed >= 1000) {
        final samplingRate =
            eventCount / (elapsed / 1000); // Divide by 1000 to get rate in Hz
        setState(() {
          gyro_sampling = samplingRate;
        });
        subscription?.cancel();
      }
    });
  }

  Future<void> _loadCustomEvents() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      customEvents = prefs.getStringList('customEvents') ?? [];
    });
  }

  Future<void> _saveCustomEvents() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setStringList('customEvents', customEvents);
  }

  void _addCustomEvent() {
    if (eventController.text.isNotEmpty) {
      setState(() {
        customEvents.add(eventController.text);
        eventController.clear();
      });
      _saveCustomEvents();
    }
  }

  void _startDateTimeTimer() {
    _dateTimeTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        DateTime now = DateTime.now();
        _currentDate = DateFormat('yyyy-MM-dd').format(now);
        _currentTime = DateFormat('HH:mm:ss').format(now);
      });
    });
  }

  void _plotData() {
    // print("accelerometerData: $_accelerometerData");
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlottingPage(
          accelerometerData: _accelerometerData,
          gyroscopeData: _gyroscopeData,
          locationData: locations,
        ),
      ),
    );
  }

  Future<Position> _getCurrentPosition() async {
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  void _updateIntervalMs(String value) {
    if(_isCollectingData){
      return;
    }
    int? newInterval = int.tryParse(value);
    if (newInterval == null) {
      newInterval = double.tryParse(value)?.round();
    }
    if (newInterval != null) {
      if (newInterval < 5) {
        newInterval = 5;
      } else if (newInterval > 5000) {
        newInterval = 5000;
      }
      setState(() {
        intervalMs = newInterval!;
      });
    }
  }

}
