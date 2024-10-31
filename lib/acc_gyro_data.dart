class AccGyroData {
  final DateTime date;
  final List<double> acc_values;
  final List<double> gyro_values;
  final double latitude;
  final double longitude;
  final String activity_name;
  final String behaviour_name;
  final String custom_event;

  AccGyroData(this.date, this.acc_values, this.gyro_values, this.latitude, this.longitude, this.activity_name, this.behaviour_name, this.custom_event);

  Map<String, dynamic> toJson() {


    return {
      'date': date.toIso8601String(),
      'Accvalue': acc_values,
      'Gyrovalue': gyro_values,
      'lat': latitude,
      'long': longitude,
      'activity_name':activity_name,
      'behaviour_name':behaviour_name,
      'custom_event':custom_event
    };
  }
}