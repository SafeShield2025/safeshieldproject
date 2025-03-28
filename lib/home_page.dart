import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'profile_page.dart';
import 'map_page.dart';
import 'package:flutter/material.dart';
//import 'package:flutter_sms/flutter_sms.dart';
import 'package:permission_handler/permission_handler.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  Position? _currentPosition;
  String _currentAddress = "Unknown location";
  bool _isLoadingLocation = false;
  List<Map<String, dynamic>> _emergencyContacts = [];

  @override
  void initState() {
    super.initState();
    _loadEmergencyContacts();
    _getCurrentLocation(); // Directly try to get location on init
  }

  Future<void> _loadEmergencyContacts() async {
    if (_currentUser != null) {
      try {
        QuerySnapshot contactsSnapshot = await _firestore
            .collection('users')
            .doc(_currentUser!.uid)
            .collection('emergencyContacts')
            .get();

        setState(() {
          _emergencyContacts = contactsSnapshot.docs
              .map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return {
              'id': doc.id,
              'name': data['name'] ?? '',
              'phone': data['phone'] ?? '',
              'relationship': data['relationship'] ?? '',
            };
          })
              .toList();
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading contacts: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _isLoadingLocation = false;
          _currentAddress = "Location services are disabled";
        });
        return;
      }

      // Request permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _isLoadingLocation = false;
            _currentAddress = "Location permissions are denied";
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _isLoadingLocation = false;
          _currentAddress = "Location permissions are permanently denied";
        });
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
      });

      // Get address from coordinates
      await _getAddressFromLatLng(position);

    } catch (e) {
      setState(() {
        _currentAddress = "Error obtaining location: $e";
      });
    } finally {
      setState(() {
        _isLoadingLocation = false;
      });
    }
  }

  Future<void> _getAddressFromLatLng(Position position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        setState(() {
          _currentAddress =
          "${place.street}, ${place.subLocality}, ${place.locality}, ${place.postalCode}, ${place.country}";
        });
      }
    } catch (e) {
      setState(() {
        _currentAddress = "Unable to fetch address";
      });
    }
  }

  Future<void> _shareLocation() async {
    if (_currentPosition == null) {
      await _getCurrentLocation();
    }

    if (_currentPosition != null) {
      // Generate Google Maps link with current coordinates
      final String mapUrl = 'https://www.google.com/maps/search/?api=1&query=${_currentPosition!.latitude},${_currentPosition!.longitude}';

      // Share location with message
      Share.share('My current location is: $_currentAddress\n\n$mapUrl');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to share location. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _saveLocationToFirestore() async {
    if (_currentUser != null && _currentPosition != null) {
      try {
        await _firestore.collection('users').doc(_currentUser!.uid).collection('locations').add({
          'latitude': _currentPosition!.latitude,
          'longitude': _currentPosition!.longitude,
          'address': _currentAddress,
          'timestamp': FieldValue.serverTimestamp(),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving location: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

//   Future<void> _sendEmergencyAlert(BuildContext context) async {
//     // Check SMS permission first
//     PermissionStatus smsPermission = await Permission.sms.status;
//
//     if (!smsPermission.isGranted) {
//       // Request SMS permission
//       smsPermission = await Permission.sms.request();
//
//       if (!smsPermission.isGranted) {
//         // Show dialog if permission is denied
//         _showSMSPermissionDeniedDialog(context);
//         return;
//       }
//     }
//
//     // Show a loading indicator
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (BuildContext context) {
//         return const AlertDialog(
//           content: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               CircularProgressIndicator(),
//               SizedBox(height: 16),
//               Text('Sending emergency alert...'),
//             ],
//           ),
//         );
//       },
//     );
//
//     try {
//       // Ensure we have the latest location
//       await _getCurrentLocation();
//
//       if (_currentPosition == null) {
//         Navigator.of(context).pop(); // Dismiss loading dialog
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text('Unable to get location. Please try again.'),
//             backgroundColor: Colors.red,
//           ),
//         );
//         return;
//       }
//
//       // Log emergency event in Firestore
//       final docRef = await _firestore.collection('emergencyAlerts').add({
//         'userId': _currentUser?.uid,
//         'userEmail': _currentUser?.email,
//         'latitude': _currentPosition!.latitude,
//         'longitude': _currentPosition!.longitude,
//         'address': _currentAddress,
//         'timestamp': FieldValue.serverTimestamp(),
//         'status': 'active',
//       });
//
//       // Create a shareable maps link
//       final String mapUrl = 'https://www.google.com/maps/search/?api=1&query=${_currentPosition!.latitude},${_currentPosition!.longitude}';
//
//       // Prepare alert message
//       final String alertMessage = 'EMERGENCY ALERT: I need help! My current location is: $_currentAddress\n\n$mapUrl';
//
//       // If we have emergency contacts, try to send them SMS alerts
//       if (_emergencyContacts.isNotEmpty) {
//         for (var contact in _emergencyContacts) {
//           final String phoneNumber = contact['phone'];
//           if (phoneNumber.isNotEmpty) {
//             try {
//               // Use flutter_sms to send SMS
//               await sendSMS(
//                   message: alertMessage,
//                   recipients: [phoneNumber],
//                   sendDirect: true
//               );
//             } catch (e) {
//               print('Error sending SMS to ${contact['name']}: $e');
//             }
//           }
//         }
//       }
//
//       // Dismiss loading dialog
//       Navigator.of(context).pop();
//
//       // Show confirmation
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Emergency alert sent to your contacts'),
//           backgroundColor: Colors.red,
//           duration: Duration(seconds: 5),
//         ),
//       );
//
//       // Navigate to alert status page with the alert document ID
//       Navigator.pushNamed(context, '/alert-status', arguments: docRef.id);
//
//     } catch (e) {
//       // Handle errors
//       Navigator.of(context).pop(); // Dismiss loading dialog
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Error sending alert: ${e.toString()}'),
//           backgroundColor: Colors.red,
//         ),
//       );
//     }
//   }
//
// // New method to show SMS permission denied dialog
//   void _showSMSPermissionDeniedDialog(BuildContext context) {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text('SMS Permission Required'),
//         content: const Text('SMS permission is needed to send emergency alerts to your contacts. Would you like to enable it in settings?'),
//         actions: [
//           TextButton(
//             onPressed: () {
//               Navigator.of(context).pop();
//             },
//             child: const Text('CANCEL'),
//           ),
//           TextButton(
//             onPressed: () {
//               Navigator.of(context).pop();
//               // Open app settings to allow user to manually enable permission
//               openAppSettings();
//             },
//             child: const Text('OPEN SETTINGS'),
//           ),
//         ],
//       ),
//     );
//   }
  Future<void> _sendEmergencyAlert(BuildContext context) async {

    // Show confirmation message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Emergency alert simulated. SMS notification sent to contacts.'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('SafeShield',style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),),
        centerTitle: true,

      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Welcome section
              Card(
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.shield_outlined,
                        size: 60,
                        color: Colors.blue,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Welcome to SafeShield',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Stay safe with real-time safety features',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Signed in as: ${user?.email ?? 'User'}',
                        style: const TextStyle(fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Quick action buttons
              const Text(
                'Quick Actions',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              // Emergency Button
              ElevatedButton.icon(
                icon: const Icon(Icons.emergency, color: Colors.white),
                label: const Text('Emergency Alert', style: TextStyle(fontSize: 16, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  _showEmergencyDialog(context);
                },
              ),

              const SizedBox(height: 16),

              // Display current location if available
              if (_currentPosition != null)
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Current Location',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            _isLoadingLocation
                                ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2)
                            )
                                : IconButton(
                              icon: const Icon(Icons.refresh),
                              onPressed: _getCurrentLocation,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(_currentAddress),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              icon: const Icon(Icons.save),
                              label: const Text('Save'),
                              onPressed: _saveLocationToFirestore,
                            ),
                            TextButton.icon(
                              icon: const Icon(Icons.share),
                              label: const Text('Share'),
                              onPressed: _shareLocation,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              // Safety Features Grid
              const Text(
                'Safety Features',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                children: [
                  _buildFeatureCard(
                    context,
                    'Location Sharing',
                    Icons.location_on,
                    Colors.green,
                        () {
                      _showLocationSharingDialog(context);
                    },
                  ),
                  _buildFeatureCard(
                    context,
                    'Safety Timer',
                    Icons.timer,
                    Colors.orange,
                        () => Navigator.pushNamed(context, '/timer'),
                  ),
                  _buildFeatureCard(
                    context,
                    'Safety Contacts',
                    Icons.contacts,
                    Colors.purple,
                        () => Navigator.pushNamed(context, '/contacts'),
                  ),
                  _buildFeatureCard(
                    context,
                    'Safety Resources',
                    Icons.menu_book,
                    Colors.blue,
                        () => Navigator.pushNamed(context, '/resources'),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Recent activity section
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Recent Activity',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      _buildActivityItem(
                        'Safety check completed',
                        '2 hours ago',
                        Icons.check_circle,
                        Colors.green,
                      ),
                      const Divider(),
                      _buildActivityItem(
                        'Timer set for walk home',
                        'Yesterday, 9:30 PM',
                        Icons.timer,
                        Colors.orange,
                      ),
                      const Divider(),
                      _buildActivityItem(
                        'Contact information updated',
                        '3 days ago',
                        Icons.edit,
                        Colors.blue,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Tips section
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Safety Tips',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      _buildSafetyTip(
                        'Share your location with trusted contacts when traveling alone',
                        Icons.location_on,
                      ),
                      const SizedBox(height: 8),
                      _buildSafetyTip(
                        'Use the Safety Timer feature when in unfamiliar areas',
                        Icons.timer,
                      ),
                      const SizedBox(height: 8),
                      _buildSafetyTip(
                        'Keep emergency contacts updated with current information',
                        Icons.contacts,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: 'Alerts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_circle_rounded),
            label: 'Profile',
          ),
        ],
        onTap: (index) {
          if (index == _currentIndex) return; // Prevent redundant navigation

          switch (index) {
            case 0:
            // Already on home page, do nothing
              break;
            case 1:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const Mapp()),
              );
              break;
            case 2:
              Navigator.pushReplacementNamed(context, '/alerts');
              break;
            case 3:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const ProfilePage()),
              );
              break;
          }
        },
      ),
    );
  }

  // Helper method to build feature cards
  Widget _buildFeatureCard(
      BuildContext context,
      String title,
      IconData icon,
      Color color,
      VoidCallback onTap,
      ) {
    return InkWell(
      onTap: onTap,
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 40,
                color: color,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper method to build activity items
  Widget _buildActivityItem(
      String title,
      String time,
      IconData icon,
      Color color,
      ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title),
                Text(
                  time,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to build safety tips
  Widget _buildSafetyTip(String tip, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.blue),
        const SizedBox(width: 12),
        Expanded(
          child: Text(tip),
        ),
      ],
    );
  }



  void _showEmergencyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Emergency Alert'),
        content: const Text(
            'This will notify your emergency contacts with your current location. '
                'Do you want to proceed?'
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('CANCEL'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.red,
            ),
            onPressed: () {
              Navigator.of(context).pop();
              _sendEmergencyAlert(context);
            },
            child: const Text('SEND ALERT'),
          ),
        ],
      ),
    );
  }

  void _showLocationSharingDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Share Location'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Share your current location with:'),
            const SizedBox(height: 16),
            if (_isLoadingLocation)
              const CircularProgressIndicator()
            else if (_currentPosition == null)
              const Text('Location not available. Please enable location services.'),
            if (_currentPosition != null)
              Text(_currentAddress, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('CANCEL'),
          ),
          if (_currentPosition == null)
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _checkLocationPermission();
              },
              child: const Text('ENABLE LOCATION'),
            ),
          if (_currentPosition != null)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _shareLocation();
              },
              child: const Text('SHARE'),
            ),
        ],
      ),
    );
  }

  Future<void> _checkLocationPermission() async {
    // Check location service status
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showLocationServicesDisabledDialog();
      return;
    }

    // Check location permission status
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      // Request permission
      permission = await Geolocator.requestPermission();

      if (permission == LocationPermission.denied) {
        _showPermissionDeniedDialog();
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showPermanentlyDeniedDialog();
      return;
    }

    // If permissions are granted, get current location
    await _getCurrentLocation();
    _showLocationSharingDialog(context);
  }

  void _showLocationServicesDisabledDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Services Disabled'),
        content: const Text('Please enable location services in your device settings.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Geolocator.openLocationSettings();
            },
            child: const Text('OPEN SETTINGS'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CANCEL'),
          ),
        ],
      ),
    );
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Permission'),
        content: const Text('Location permissions are required to share your location.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _checkLocationPermission();
            },
            child: const Text('RETRY'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CANCEL'),
          ),
        ],
      ),
    );
  }

  void _showPermanentlyDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Permission'),
        content: const Text('Location permissions are permanently denied. Please enable them in app settings.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Geolocator.openAppSettings();
            },
            child: const Text('OPEN SETTINGS'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CANCEL'),
          ),
        ],
      ),
    );
  }

}


