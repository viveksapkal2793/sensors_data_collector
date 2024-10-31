class AccelerometerData {
  final DateTime date;
  final List<double> values;
  final String activity_name;
  final String behaviour_name;
  final String custom_event;

  AccelerometerData(this.date, this.values, this.activity_name, this.behaviour_name, this.custom_event);

  Map<String, dynamic> toJson() {


    return {
      'date': date.toIso8601String(),
      'value': values,
      'activity_name':activity_name,
      'behaviour_name':behaviour_name,
      'custom_event':custom_event
    };
  }
}

