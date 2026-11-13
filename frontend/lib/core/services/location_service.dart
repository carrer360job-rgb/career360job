import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;

class LocationResult {
  final String state;
  final String district;
  final double latitude;
  final double longitude;

  LocationResult({
    required this.state,
    required this.district,
    required this.latitude,
    required this.longitude,
  });
}

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  /// All 28 States and 8 Union Territories of India
  static const List<String> indianStates = [
    'Tamil Nadu',
    'Karnataka',
    'Kerala',
    'Andhra Pradesh',
    'Telangana',
    'Maharashtra',
    'Delhi (NCT)',
    'Uttar Pradesh',
    'Gujarat',
    'West Bengal',
    'Rajasthan',
    'Madhya Pradesh',
    'Bihar',
    'Punjab',
    'Haryana',
    'Odisha',
    'Assam',
    'Jharkhand',
    'Chhattisgarh',
    'Uttarakhand',
    'Himachal Pradesh',
    'Goa',
    'Jammu and Kashmir',
    'Chandigarh',
    'Puducherry',
    'Tripura',
    'Meghalaya',
    'Manipur',
    'Nagaland',
    'Mizoram',
    'Sikkim',
    'Arunachal Pradesh',
    'Ladakh',
    'Andaman and Nicobar Islands',
    'Dadra and Nagar Haveli and Daman and Diu',
    'Lakshadweep',
  ];

  /// Official districts categorized by State
  static const Map<String, List<String>> districtsByState = {
    'Tamil Nadu': [
      'Ariyalur',
      'Chengalpattu',
      'Chennai',
      'Coimbatore',
      'Cuddalore',
      'Dharmapuri',
      'Dindigul',
      'Erode',
      'Kallakurichi',
      'Kanchipuram',
      'Kanyakumari',
      'Karur',
      'Krishnagiri',
      'Madurai',
      'Mayiladuthurai',
      'Nagapattinam',
      'Namakkal',
      'Nilgiris',
      'Perambalur',
      'Pudukkottai',
      'Ramanathapuram',
      'Ranipet',
      'Salem',
      'Sivaganga',
      'Tenkasi',
      'Thanjavur',
      'Theni',
      'Thoothukudi',
      'Tiruchirappalli',
      'Tirunelveli',
      'Tirupathur',
      'Tiruppur',
      'Tiruvallur',
      'Tiruvannamalai',
      'Tiruvarur',
      'Vellore',
      'Viluppuram',
      'Virudhunagar',
    ],
    'Karnataka': [
      'Bengaluru Urban',
      'Bengaluru Rural',
      'Mysuru',
      'Dakshina Kannada (Mangaluru)',
      'Belagavi',
      'Hubballi-Dharwad',
      'Tumakuru',
      'Shivamogga',
      'Ballari',
      'Udupi',
      'Hassan',
      'Davanagere',
      'Kalaburagi',
      'Mandya',
      'Kolar',
      'Chikkamagaluru',
      'Chikkaballapur',
      'Ramanagara',
      'Raichur',
      'Bidar',
      'Bagalkot',
      'Vijayapura',
      'Gadag',
      'Haveri',
      'Koppal',
      'Yadgir',
      'Kodagu',
      'Uttara Kannada',
      'Chamarajanagar',
    ],
    'Kerala': [
      'Alappuzha',
      'Ernakulam (Kochi)',
      'Idukki',
      'Kannur',
      'Kasaragod',
      'Kollam',
      'Kottayam',
      'Kozhikode',
      'Malappuram',
      'Palakkad',
      'Pathanamthitta',
      'Thiruvananthapuram',
      'Thrissur',
      'Wayanad',
    ],
    'Maharashtra': [
      'Mumbai City',
      'Mumbai Suburban',
      'Pune',
      'Thane',
      'Nagpur',
      'Nashik',
      'Aurangabad (Chhatrapati Sambhaji Nagar)',
      'Solapur',
      'Kolhapur',
      'Navi Mumbai',
      'Amravati',
      'Nanded',
      'Sangli',
      'Jalgaon',
      'Akola',
      'Latur',
      'Dhule',
      'Ahmednagar',
      'Chandrapur',
      'Parbhani',
      'Raigad',
      'Satara',
      'Ratnagiri',
    ],
    'Telangana': [
      'Hyderabad',
      'Medchal-Malkajgiri',
      'Rangareddy',
      'Warangal',
      'Hanamkonda',
      'Karimnagar',
      'Nizamabad',
      'Khammam',
      'Nalgonda',
      'Sangareddy',
      'Siddipet',
      'Mahabubnagar',
      'Bhadradri Kothagudem',
      'Jagtial',
      'Mancherial',
      'Suryapet',
    ],
    'Andhra Pradesh': [
      'Visakhapatnam',
      'NTR (Vijayawada)',
      'Guntur',
      'Tirupati',
      'Kurnool',
      'Nellore',
      'Kakinada',
      'Ananthapuramu',
      'YSR Kadapa',
      'Chittoor',
      'East Godavari',
      'West Godavari',
      'Srikakulam',
      'Vizianagaram',
      'Prakasam',
      'Eluru',
    ],
    'Delhi (NCT)': [
      'New Delhi',
      'Central Delhi',
      'South Delhi',
      'South East Delhi',
      'South West Delhi',
      'North Delhi',
      'North East Delhi',
      'North West Delhi',
      'East Delhi',
      'West Delhi',
      'Shahdara',
    ],
    'Uttar Pradesh': [
      'Gautam Buddha Nagar (Noida)',
      'Lucknow',
      'Kanpur Nagar',
      'Ghaziabad',
      'Varanasi',
      'Prayagraj',
      'Agra',
      'Meerut',
      'Bareilly',
      'Aligarh',
      'Moradabad',
      'Gorakhpur',
      'Ayodhya',
      'Jhansi',
      'Mathura',
    ],
    'Gujarat': [
      'Ahmedabad',
      'Surat',
      'Vadodara',
      'Rajkot',
      'Bhavnagar',
      'Jamnagar',
      'Gandhinagar',
      'Junagadh',
      'Anand',
      'Kutch',
      'Bharuch',
      'Navsari',
      'Valsad',
    ],
    'West Bengal': [
      'Kolkata',
      'North 24 Parganas',
      'South 24 Parganas',
      'Howrah',
      'Hooghly',
      'Darjeeling (Siliguri)',
      'Paschim Medinipur',
      'Purba Medinipur',
      'Paschim Bardhaman (Asansol)',
      'Purba Bardhaman',
      'Murshidabad',
      'Nadia',
      'Malda',
      'Jalpaiguri',
    ],
    'Rajasthan': [
      'Jaipur',
      'Jodhpur',
      'Udaipur',
      'Kota',
      'Bikaner',
      'Ajmer',
      'Alwar',
      'Bhilwara',
      'Sikar',
      'Bharatpur',
      'Pali',
      'Sri Ganganagar',
    ],
    'Madhya Pradesh': [
      'Bhopal',
      'Indore',
      'Jabalpur',
      'Gwalior',
      'Ujjain',
      'Sagar',
      'Dewas',
      'Satna',
      'Ratlam',
      'Rewa',
    ],
  };

  /// Returns districts for the given state
  static List<String> getDistrictsForState(String state) {
    if (districtsByState.containsKey(state)) {
      return districtsByState[state]!;
    }
    for (final entry in districtsByState.entries) {
      if (entry.key.toLowerCase() == state.toLowerCase() ||
          entry.key.toLowerCase().contains(state.toLowerCase()) ||
          state.toLowerCase().contains(entry.key.toLowerCase())) {
        return entry.value;
      }
    }
    return [
      'Central District',
      'North District',
      'South District',
      'East District',
      'West District',
    ];
  }

  /// Checks location permission, then detects the current state and district.
  Future<LocationResult?> detectCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[LocationService] Location service is disabled on device.');
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('[LocationService] Location permission denied by user.');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('[LocationService] Location permission permanently denied.');
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );

      String detectedState = '';
      String detectedDistrict = '';

      // 1. Primary: High-accuracy free reverse geocoding via BigDataCloud client API
      try {
        final uri = Uri.parse(
          'https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=${position.latitude}&longitude=${position.longitude}&localityLanguage=en',
        );
        final response = await http
            .get(uri)
            .timeout(const Duration(seconds: 4));
        if (response.statusCode == 200) {
          final data = json.decode(response.body) as Map<String, dynamic>;
          final state = data['principalSubdivision']?.toString().trim() ?? '';

          String foundDistrict = '';
          final localityInfo =
              data['localityInfo'] as Map<String, dynamic>? ?? {};
          final adminList = localityInfo['administrative'] as List? ?? [];
          for (final item in adminList) {
            if (item is Map) {
              final name = item['name']?.toString().trim() ?? '';
              final desc = item['description']?.toString().toLowerCase() ?? '';
              final order = item['order'] as int? ?? 0;
              if (desc.contains('district') ||
                  name.toLowerCase().contains('district') ||
                  order == 9) {
                foundDistrict = name
                    .replaceAll(
                      RegExp(r'\s+district', caseSensitive: false),
                      '',
                    )
                    .trim();
                break;
              }
            }
          }

          if (state.isNotEmpty) detectedState = state;
          if (foundDistrict.isNotEmpty) {
            detectedDistrict = foundDistrict;
          }
        }
      } catch (netErr) {
        debugPrint(
          '[LocationService] BigDataCloud reverse geocoding fallback: $netErr',
        );
      }

      // 2. Secondary: Device native CLGeocoder / Android Geocoder fallback
      if (detectedState.isEmpty || detectedDistrict.isEmpty) {
        try {
          final geocoding = Geocoding();
          final placemarks = await geocoding.placemarkFromCoordinates(
            position.latitude,
            position.longitude,
          );

          if (placemarks.isNotEmpty) {
            final p = placemarks.first;
            final subAdmin = p.subAdministrativeArea?.trim() ?? '';
            final admin = p.administrativeArea?.trim() ?? '';

            if (detectedState.isEmpty && admin.isNotEmpty) {
              detectedState = admin;
            }
            if (detectedDistrict.isEmpty && subAdmin.isNotEmpty) {
              detectedDistrict = subAdmin;
            }
          }
        } catch (geoError) {
          debugPrint(
            '[LocationService] Native geocoding fallback error: $geoError',
          );
        }
      }

      // 3. Match against known State names to ensure exact spelling match
      for (final s in indianStates) {
        if (detectedState.toLowerCase() == s.toLowerCase() ||
            detectedState.toLowerCase().contains(s.toLowerCase())) {
          detectedState = s;
          break;
        }
      }

      // 4. Match against known District names for that state to ensure exact casing
      final knownDistricts = getDistrictsForState(detectedState);
      if (detectedDistrict.isNotEmpty) {
        for (final d in knownDistricts) {
          if (detectedDistrict.toLowerCase() == d.toLowerCase() ||
              detectedDistrict.toLowerCase().contains(d.toLowerCase()) ||
              d.toLowerCase().contains(detectedDistrict.toLowerCase())) {
            detectedDistrict = d;
            break;
          }
        }
      }

      if (detectedState.isEmpty || detectedDistrict.isEmpty) return null;

      return LocationResult(
        state: detectedState,
        district: detectedDistrict,
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (e) {
      debugPrint('[LocationService] Error detecting location: $e');
      return null;
    }
  }
}
