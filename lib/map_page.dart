import 'dart:convert';
import 'dart:math';
import 'GMAPAPI.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:http/http.dart' as http;
import 'package:google_place/google_place.dart';



class Mapp extends StatelessWidget {
  const Mapp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SafeShield',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        appBarTheme: AppBarTheme(
          elevation: 0,
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.deepPurple.shade100),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.deepPurple.shade100),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.deepPurple, width: 2),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      home: const MapPage(),
    );
  }
}

class MapPage extends StatefulWidget {
  const MapPage({Key? key}) : super(key: key);

  @override
  State<MapPage> createState() => _SafeShieldHomePageState();
}

class _SafeShieldHomePageState extends State<MapPage> {
  static const String _googlePlacesApiKey = goopleplacesapi;
  late GooglePlace googlePlace;
  GoogleMapController? _mapController;
  List<AutocompletePrediction> startpredictions = [];
  List<AutocompletePrediction> destpredictions = [];
  Position? _currentPosition;
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  final FocusNode _startFocusNode = FocusNode();
  final FocusNode _destinationFocusNode = FocusNode();

  LatLng? _startLocation;
  LatLng? _destinationLocation;

  List<CrimeZone> _crimeZones = [];
  Set<Marker> _markers = {};
  Set<Circle> _circles = {};
  Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    googlePlace = GooglePlace(_googlePlacesApiKey);

    _startFocusNode.addListener(() {
      if (!_startFocusNode.hasFocus) setState(() => startpredictions = []);
    });

    _destinationFocusNode.addListener(() {
      if (!_destinationFocusNode.hasFocus) setState(() => destpredictions = []);
    });

    _getCurrentLocation();
  }

  Future<void> _loadCrimeData() async {
    try {
      // Load crime data from assets
      final String response = await rootBundle.loadString('assets/crime_data.json');
      final data = await json.decode(response);

      setState(() {
        _crimeZones = List<CrimeZone>.from(
            data['crime_zones'].map((zone) => CrimeZone.fromJson(zone))
        );
        _displayCrimeZones();
      });
    } catch (e) {
      print("Error loading crime data: $e");
      // Use mock data if loading fails;
    }
  }
  void _displayCrimeZones() {
    Set<Circle> circles = {};

    for (var zone in _crimeZones) {
      // Determine color based on crime rate
      Color zoneColor;
      if (zone.crimeRate >= 8.0) {
        zoneColor = Colors.red.withOpacity(0.3);
      } else if (zone.crimeRate >= 5.0) {
        zoneColor = Colors.orange.withOpacity(0.3);
      } else {
        zoneColor = Colors.yellow.withOpacity(0.3);
      }

      circles.add(
        Circle(
          circleId: CircleId(zone.id),
          center: zone.center,
          radius: zone.radius,
          fillColor: zoneColor,
          strokeWidth: 2,
          strokeColor: zoneColor.withOpacity(0.7),
        ),
      );
    }

    setState(() {
      _circles = circles;
    });
  }

  Future<void> _getCurrentLocation() async {
    _loadCrimeData();
    LocationPermission permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) return;

    _currentPosition = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    setState(() {
      _markers.add(
        Marker(
          markerId: const MarkerId("currentLocation"),
          position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          infoWindow: const InfoWindow(title: 'Your Location'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        ),
      );
    });
  }
  void _generateRoute() async {
    if (_startLocation == null || _destinationLocation == null) return;
    setState(() {
      _markers.clear();
      _markers.add(Marker(
          markerId: const MarkerId('start'),
          position: _startLocation!,
          infoWindow: InfoWindow(title: _startController.text)
      ));
      _markers.add(Marker(
          markerId: const MarkerId('destination'),
          position: _destinationLocation!,
          infoWindow: InfoWindow(title: _destinationController.text)
      ));
    });
    final String url = 'https://maps.googleapis.com/maps/api/directions/json?origin=${_startLocation!.latitude},${_startLocation!.longitude}&destination=${_destinationLocation!.latitude},${_destinationLocation!.longitude}&key=$_googlePlacesApiKey';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          // Decode the route points
          List<LatLng> routePoints = [];
          List routes = data['routes'];
          if (routes.isNotEmpty) {
            List legs = routes[0]['legs'];
            if (legs.isNotEmpty) {
              List steps = legs[0]['steps'];

              for (var step in steps) {
                // Decode the polyline points
                PolylinePoints polylinePoints = PolylinePoints();
                List<PointLatLng> decodedPoints = polylinePoints.decodePolyline(step['polyline']['points']);

                // Convert decoded points to LatLng
                routePoints.addAll(decodedPoints.map((point) =>
                    LatLng(point.latitude, point.longitude)
                ));
              }
            }
          }

          // Update the polyline with the actual route
          setState(() {
            _polylines.clear();
            _polylines.add(Polyline(
              polylineId: const PolylineId('route'),
              points: routePoints,
              color: Colors.blue,
              width: 5,
            ));

            // Adjust camera to show the entire route
            if (_mapController != null) {
              _mapController!.animateCamera(
                  CameraUpdate.newLatLngBounds(
                      _getBounds(routePoints),
                      50 // padding
                  )
              );
            }
          });
        } else {
          _showErrorDialog('Unable to generate route: ${data['status']}');
        }
      } else {
        _showErrorDialog('Failed to fetch route. Status code: ${response.statusCode}');
      }
    } catch (e) {
      _showErrorDialog('Error generating route: $e');
    }
  }

  LatLngBounds _getBounds(List<LatLng> points) {
    double minLat = points.map((p) => p.latitude).reduce(min);
    double maxLat = points.map((p) => p.latitude).reduce(max);
    double minLng = points.map((p) => p.longitude).reduce(min);
    double maxLng = points.map((p) => p.longitude).reduce(max);

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Route Error'),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
  void _onSearchstart(String value) async {
    if (value.isNotEmpty) {
      var result = await googlePlace.autocomplete.get(value);
      if (result != null && result.predictions != null) {
        setState(() {
          startpredictions = result.predictions!;
        });
      }
    } else {
      setState(() {
        startpredictions = [];
      });
    }
  }
  void _onSearchend(String value) async {
    if (value.isNotEmpty) {
      var result = await googlePlace.autocomplete.get(value);
      if (result != null && result.predictions != null) {
        setState(() {
          destpredictions = result.predictions!;
        });
      }
    } else {
      setState(() {
        destpredictions = [];
      });
    }
  }
  void _onSelectPlace(AutocompletePrediction prediction, bool isStart) async {
    String placeName = prediction.description ?? "";
    TextEditingController controller = isStart ? _startController : _destinationController;

    controller.text = placeName;

    var details = await googlePlace.details.get(prediction.placeId!);
    if (details != null && details.result != null) {
      double lat = details.result!.geometry!.location!.lat!;
      double lng = details.result!.geometry!.location!.lng!;

      setState(() {
        if (isStart) {
          _startLocation = LatLng(lat, lng);
          _startController.text = placeName;
        } else {
          _destinationLocation = LatLng(lat, lng);
          _destinationController.text = placeName;
        }
        startpredictions = [];
        destpredictions = [];// Clear predictions for both start and destination
      });


      // Automatically generate route if both locations are selected
      if (_startLocation != null && _destinationLocation != null) {
        _generateRoute();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.security, color: Colors.white),
            SizedBox(width: 10),
            Text('SafeShield', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.my_location),
            onPressed: _getCurrentLocation,
            tooltip: 'Refresh Location',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildLocationTextField(
                  controller: _startController,
                  focusNode: _startFocusNode,
                  onChanged: _onSearchstart,
                  hintText: "Start Location",
                  predictions: startpredictions,
                  isStart: true,
                ),
                SizedBox(height: 16),
                _buildLocationTextField(
                  controller: _destinationController,
                  focusNode: _destinationFocusNode,
                  onChanged: _onSearchend,
                  hintText: "Destination Location",
                  predictions: destpredictions,
                  isStart: false,
                ),
                SizedBox(height: 16),
                _startLocation != null && _destinationLocation != null
                    ? ElevatedButton.icon(
                  onPressed: _generateRoute,
                  icon: Icon(Icons.directions),
                  label: Text('Generate Safe Route'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(double.infinity, 50),
                  ),
                )
                    : Container(),
              ],
            ),
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, -5),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                child: GoogleMap(
                  onMapCreated: (controller) => _mapController = controller,
                  initialCameraPosition: CameraPosition(
                    target: _currentPosition != null
                        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
                        : const LatLng(20.5937, 78.9629),
                    zoom: 5.0,
                  ),
                  myLocationEnabled: true,
                  markers: _markers,
                  polylines: _polylines,
                  circles: _circles,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required void Function(String) onChanged,
    required String hintText,
    required List<AutocompletePrediction> predictions,
    required bool isStart,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          focusNode: focusNode,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: Icon(Icons.location_on, color: Colors.deepPurple),
            suffixIcon: controller.text.isNotEmpty
                ? IconButton(
              icon: Icon(Icons.clear, color: Colors.deepPurple),
              onPressed: () {
                controller.clear();
                setState(() {
                  if (isStart) {
                    _startLocation = null;
                    startpredictions = [];
                  } else {
                    _destinationLocation = null;
                    destpredictions = [];
                  }
                });
              },
            )
                : null,
          ),
        ),
        if (predictions.isNotEmpty)
          Container(
            margin: EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: predictions.length,
              separatorBuilder: (context, index) => Divider(height: 1),
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(
                    predictions[index].description ?? "",
                    style: TextStyle(color: Colors.deepPurple),
                  ),
                  leading: Icon(Icons.place, color: Colors.deepPurple),
                  onTap: () => _onSelectPlace(predictions[index], isStart),
                );
              },
            ),
          ),
      ],
    );
  }

// Rest of the code remains the same
}
class CrimeZone {
  final String id;
  final LatLng center;
  final double radius;
  final double crimeRate; // 0-10 scale, 10 being highest

  CrimeZone({
    required this.id,
    required this.center,
    required this.radius,
    required this.crimeRate,
  });

  factory CrimeZone.fromJson(Map<String, dynamic> json) {
    return CrimeZone(
      id: json['id'],
      center: LatLng(json['latitude'], json['longitude']),
      radius: json['radius'].toDouble(),
      crimeRate: json['crime_rate'].toDouble(),
    );
  }
}
// CrimeZone class remains the same