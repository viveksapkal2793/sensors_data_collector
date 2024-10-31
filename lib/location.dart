class location_data{
  final double lat;
  final double long;
  final String activity_name;
  final String behaviour_name;
  final String custom_event;
  final DateTime date;

  location_data(this.date, this.lat,this.long, this.activity_name, this.behaviour_name, this.custom_event);

  Map<String, dynamic> toJson(){
    return {
      'date':date.toIso8601String(),
      'lat': lat,
      'long': long,
      'activity_name':activity_name,
      'behaviour_name':behaviour_name,
      'custom_event':custom_event
    };
  }
}