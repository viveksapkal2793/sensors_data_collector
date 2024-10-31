import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
// import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:typed_data';
import 'accelerometer_data.dart';
import 'gyroscope_data.dart';
import 'location.dart';
import 'dart:ui' as ui;

class PlottingPage extends StatelessWidget {
  final List<AccelerometerData> accelerometerData;
  final List<GyroscopeData> gyroscopeData;
  final List<location_data> locationData;

  PlottingPage({
    required this.accelerometerData,
    required this.gyroscopeData,
    required this.locationData,
  });

  Future<void> _savePlotAsImage(GlobalKey key, String fileName) async {
    RenderRepaintBoundary boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    var image = await boundary.toImage();
    ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    Uint8List pngBytes = byteData!.buffer.asUint8List();

    final directory = Directory('/storage/emulated/0/Download');
    if (!await directory.exists()) {
      print("Error: Unable to access download directory.");
      return;
    }
    final path = '${directory.path}/$fileName.png';
    final file = File(path);
    await file.writeAsBytes(pngBytes);
  }

  List<_ChartData> _convertToChartData(List<dynamic> data, String axis) {
    print("Converting data for axis: $axis");
    print("Original data: $data");
    List<_ChartData> chartData = data.asMap().entries.map((entry) {
      int index = entry.key;
      var value = entry.value;
      double yValue;
      switch (axis) {
        case 'x':
          yValue = value.values[0];
          break;
        case 'y':
          yValue = value.values[1];
          break;
        case 'z':
          yValue = value.values[2];
          break;
        case 'lat':
          yValue = value.lat;
          break;
        case 'long':
          yValue = value.long;
          break;
        default:
          yValue = 0.0;
      }
      return _ChartData(index.toDouble(), yValue);
    }).toList();
    print("Converted chart data: $chartData");
    return chartData;
  }

  @override
  Widget build(BuildContext context) {
    final GlobalKey key1 = GlobalKey();
    final GlobalKey key2 = GlobalKey();
    final GlobalKey key3 = GlobalKey();
    final GlobalKey key4 = GlobalKey();
    final GlobalKey key5 = GlobalKey();
    final GlobalKey key6 = GlobalKey();
    final GlobalKey key7 = GlobalKey();
    final GlobalKey key8 = GlobalKey();

    return Scaffold(
      appBar: AppBar(
        title: Text('Data Plots'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildPlotSection(
              context,
              key1,
              'Accelerometer Data - X',
              _convertToChartData(accelerometerData, 'x'),
            ),
            _buildPlotSection(
              context,
              key2,
              'Accelerometer Data - Y',
              _convertToChartData(accelerometerData, 'y'),
            ),
            _buildPlotSection(
              context,
              key3,
              'Accelerometer Data - Z',
              _convertToChartData(accelerometerData, 'z'),
            ),
            _buildPlotSection(
              context,
              key4,
              'Gyroscope Data - X',
              _convertToChartData(gyroscopeData, 'x'),
            ),
            _buildPlotSection(
              context,
              key5,
              'Gyroscope Data - Y',
              _convertToChartData(gyroscopeData, 'y'),
            ),
            _buildPlotSection(
              context,
              key6,
              'Gyroscope Data - Z',
              _convertToChartData(gyroscopeData, 'z'),
            ),
            _buildPlotSection(
              context,
              key7,
              'Location Data - Latitude',
              _convertToChartData(locationData, 'lat'),
            ),
            _buildPlotSection(
              context,
              key8,
              'Location Data - Longitude',
              _convertToChartData(locationData, 'long'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlotSection(BuildContext context, GlobalKey key, String title, List<_ChartData> data) {
    print("Building plot section for: $title with data: $data");
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          RepaintBoundary(
            key: key,
            child: Container(
              height: 200,
              child: SfCartesianChart(
                primaryXAxis: NumericAxis(),
                title: ChartTitle(text: title),
                legend: Legend(isVisible: true),
                tooltipBehavior: TooltipBehavior(enable: true),
                series: <ChartSeries>[
                  LineSeries<_ChartData, double>(
                    dataSource: data,
                    xValueMapper: (_ChartData data, _) => data.x,
                    yValueMapper: (_ChartData data, _) => data.y,
                    name: 'Data',
                    dataLabelSettings: DataLabelSettings(isVisible: true),
                  )
                ],
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: Icon(Icons.fullscreen),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FullScreenPlot(data: data, title: title),
                    ),
                  );
                },
              ),
              IconButton(
                icon: Icon(Icons.save),
                onPressed: () => _savePlotAsImage(key, title),
              ),
              IconButton(
                icon: Icon(Icons.close),
                onPressed: () {
                  // Close the plot section
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class FullScreenPlot extends StatelessWidget {
  final List<_ChartData> data;
  final String title;

  FullScreenPlot({required this.data, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Center(
        child: SfCartesianChart(
          primaryXAxis: NumericAxis(),
          title: ChartTitle(text: title),
          legend: Legend(isVisible: true),
          tooltipBehavior: TooltipBehavior(enable: true),
          series: <ChartSeries>[
            LineSeries<_ChartData, double>(
              dataSource: data,
              xValueMapper: (_ChartData data, _) => data.x,
              yValueMapper: (_ChartData data, _) => data.y,
              name: 'Data',
              dataLabelSettings: DataLabelSettings(isVisible: true),
            )
          ],
        ),
      ),
    );
  }
}

class _ChartData {
  _ChartData(this.x, this.y);

  final double x;
  final double y;

  @override
  String toString() {
    return '(_ChartData(x: $x, y: $y))';
  }
}