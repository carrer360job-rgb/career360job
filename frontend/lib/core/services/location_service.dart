import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;

class LocationResult {
  final String state;
  final String district;
  final String city;
  final double latitude;
  final double longitude;

  LocationResult({
    required this.state,
    required this.district,
    required this.city,
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

  /// Common cities/towns/neighborhoods by district
  static const Map<String, List<String>> citiesByDistrict = {
    // Tamil Nadu
    'Erode': ['Chennimalai', 'Perundurai', 'Bhavani', 'Gobichettipalayam', 'Erode Town', 'Sathyamangalam', 'Anthiyur', 'Kodumudi', 'Modakkurichi'],
    'Coimbatore': ['Gandhipuram', 'RS Puram', 'Saravanampatti', 'Peelamedu', 'Pollachi', 'Singanallur', 'Kuniyamuthur', 'Mettupalayam', 'Thudiyalur', 'Sulur', 'Kinathukadavu'],
    'Chennai': ['Guindy', 'OMR / Sholinganallur', 'T. Nagar', 'Velachery', 'Anna Nagar', 'Adyar', 'Tambaram', 'Porur', 'Perambur', 'Mylapore', 'Chromepet', 'Ambattur'],
    'Tiruppur': ['Tiruppur City', 'Avinashi', 'Palladam', 'Udumalaipettai', 'Kangeyam', 'Dharapuram', 'Madathukulam', 'Vellakoil'],
    'Salem': ['Salem South', 'Salem West', 'Attur', 'Mettur', 'Omalur', 'Edappadi', 'Sankagiri', 'Yercaud', 'Valapady'],
    'Madurai': ['Mattuthavani', 'KK Nagar', 'Thirunagar', 'Anna Nagar', 'Simmakkal', 'Thiruparankundram', 'Usilampatti', 'Melur', 'Vadipatti'],
    'Tiruchirappalli': ['Thillai Nagar', 'Cantonment', 'Srirangam', 'KK Nagar', 'Thuvakudi', 'Lalgudi', 'Manapparai', 'Musiri'],
    'Tirunelveli': ['Palayamkottai', 'Tirunelveli Town', 'Ambasamudram', 'Nanguneri', 'Vallioor'],
    'Vellore': ['Vellore Town', 'Katpadi', 'Gudiyatham', 'Anaicut', 'Kaniyambadi'],
    'Dindigul': ['Dindigul Town', 'Palani', 'Kodaikanal', 'Oddanchatram', 'Natham'],
    'Thanjavur': ['Thanjavur Town', 'Kumbakonam', 'Pattukkottai', 'Orathanadu', 'Thiruvaiyaru'],
    'Kanchipuram': ['Kanchipuram Town', 'Sriperumbudur', 'Walajabad', 'Uthiramerur'],
    'Chengalpattu': ['Chengalpattu Town', 'Tambaram South', 'Maraimalai Nagar', 'Mahabalipuram', 'Maduranthakam'],
    'Namakkal': ['Namakkal Town', 'Tiruchengode', 'Rasipuram', 'Paramathi Velur', 'Kolli Hills'],
    'Karur': ['Karur Town', 'Kulithalai', 'Aravakurichi', 'Krishnarayapuram'],
    'Krishnagiri': ['Hosur', 'Krishnagiri Town', 'Pochampalli', 'Uthangarai', 'Denkanikottai'],
    'Kanyakumari': ['Nagercoil', 'Kanyakumari Town', 'Thuckalay', 'Colachel', 'Marthandam'],

    // Karnataka
    'Bengaluru Urban': ['Koramangala', 'Whitefield', 'Indiranagar', 'HSR Layout', 'Electronic City', 'Marathahalli', 'Jayanagar', 'BTM Layout', 'Hebbal', 'Yelahanka', 'Banashankari', 'Rajajinagar'],
    'Mysuru': ['Gokulam', 'Vijayanagar', 'Jayalakshmipuram', 'Hebbal 1st Stage', 'Kuvempunagar', 'Saraswathipuram'],
    'Dakshina Kannada (Mangaluru)': ['Hampankatta', 'Kadri', 'Bejai', 'Kankanady', 'Surathkal', 'Ullal'],

    // Maharashtra
    'Mumbai Suburban': ['Andheri', 'Bandra', 'Borivali', 'Goregaon', 'Malad', 'Juhu', 'Kurla', 'Ghatkopar', 'Mulund', 'Powai'],
    'Mumbai City': ['Colaba', 'Nariman Point', 'Fort', 'Marine Lines', 'Dadra', 'Worli', 'Lower Parel'],
    'Pune': ['Hinjewadi', 'Kothrud', 'Viman Nagar', 'Koregaon Park', 'Shivajinagar', 'Hadapsar', 'Baner', 'Wakad', 'Magarpatta'],

    // Telangana
    'Hyderabad': ['Hitec City', 'Madhapur', 'Gachibowli', 'Jubilee Hills', 'Banjara Hills', 'Kondapur', 'Kukatpally', 'Ameerpet', 'Begumpet', 'Secunderabad'],

    // Kerala
    'Ernakulam (Kochi)': ['Fort Kochi', 'Marine Drive', 'Kaloor', 'Edapally', 'Kakkanad (Infopark)', 'Palarivattom', 'Vyttila', 'Aluva'],
    'Thiruvananthapuram': ['Technopark', 'Kowdiar', 'Pattom', 'Palayam', 'Kazhakoottam', 'Vellayambalam'],

    // Delhi
    'New Delhi': ['Connaught Place', 'Chanakyapuri', 'Barakhamba Road', 'Janpath'],
    'South Delhi': ['Hauz Khas', 'Saket', 'Greater Kailash', 'Lajpat Nagar', 'Vasant Kunj'],
    'Gautam Buddha Nagar (Noida)': ['Sector 62', 'Sector 18', 'Sector 137', 'Greater Noida Knowledge Park', 'Sector 15'],
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

  /// Returns cities/towns for the given district
  static List<String> getCitiesForDistrict(String district) {
    if (citiesByDistrict.containsKey(district)) {
      return citiesByDistrict[district]!;
    }
    for (final entry in citiesByDistrict.entries) {
      if (entry.key.toLowerCase() == district.toLowerCase() ||
          entry.key.toLowerCase().contains(district.toLowerCase()) ||
          district.toLowerCase().contains(entry.key.toLowerCase())) {
        return entry.value;
      }
    }
    return [
      '$district Town',
      'City Center',
      'Main Market',
      'Industrial Area',
    ];
  }

  /// Returns the sensible default city/town for a given district
  static String getDefaultCityForDistrict(String district) {
    if (district.trim().isEmpty) return '';
    final list = getCitiesForDistrict(district);
    if (list.isNotEmpty) return list.first;
    return '$district Town';
  }

  /// Checks and requests location permission, then detects current State, District, and City
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
      String detectedCity = '';

      // 1. Primary: High-accuracy free reverse geocoding via BigDataCloud client API
      try {
        final uri = Uri.parse(
          'https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=${position.latitude}&longitude=${position.longitude}&localityLanguage=en',
        );
        final response = await http.get(uri).timeout(const Duration(seconds: 4));
        if (response.statusCode == 200) {
          final data = json.decode(response.body) as Map<String, dynamic>;
          final state = data['principalSubdivision']?.toString().trim() ?? '';
          final city = data['city']?.toString().trim() ?? '';
          final locality = data['locality']?.toString().trim() ?? '';

          String foundDistrict = '';
          final localityInfo = data['localityInfo'] as Map<String, dynamic>? ?? {};
          final adminList = localityInfo['administrative'] as List? ?? [];
          for (final item in adminList) {
            if (item is Map) {
              final name = item['name']?.toString().trim() ?? '';
              final desc = item['description']?.toString().toLowerCase() ?? '';
              final order = item['order'] as int? ?? 0;
              if (desc.contains('district') || name.toLowerCase().contains('district') || order == 9) {
                foundDistrict = name.replaceAll(RegExp(r'\s+district', caseSensitive: false), '').trim();
                break;
              }
            }
          }

          if (state.isNotEmpty) detectedState = state;
          if (foundDistrict.isNotEmpty) {
            detectedDistrict = foundDistrict;
          } else if (city.isNotEmpty) {
            detectedDistrict = city;
          }

          if (locality.isNotEmpty) {
            detectedCity = locality;
          } else if (city.isNotEmpty) {
            detectedCity = city;
          }
        }
      } catch (netErr) {
        debugPrint('[LocationService] BigDataCloud reverse geocoding fallback: $netErr');
      }

      // 2. Secondary: Device native CLGeocoder / Android Geocoder fallback
      if (detectedCity.isEmpty || detectedDistrict.isEmpty) {
        try {
          final geocoding = Geocoding();
          final placemarks = await geocoding.placemarkFromCoordinates(
            position.latitude,
            position.longitude,
          );

          if (placemarks.isNotEmpty) {
            final p = placemarks.first;
            final locality = p.locality?.trim() ?? '';
            final subAdmin = p.subAdministrativeArea?.trim() ?? '';
            final admin = p.administrativeArea?.trim() ?? '';
            final subLocality = p.subLocality?.trim() ?? '';

            if (detectedState.isEmpty && admin.isNotEmpty) detectedState = admin;
            if (detectedDistrict.isEmpty) {
              detectedDistrict = subAdmin.isNotEmpty ? subAdmin : (locality.isNotEmpty ? locality : admin);
            }
            if (detectedCity.isEmpty) {
              detectedCity = locality.isNotEmpty ? locality : (subLocality.isNotEmpty ? subLocality : subAdmin);
            }
          }
        } catch (geoError) {
          debugPrint('[LocationService] Native geocoding fallback error: $geoError');
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
      for (final d in knownDistricts) {
        if (detectedDistrict.toLowerCase() == d.toLowerCase() ||
            detectedDistrict.toLowerCase().contains(d.toLowerCase()) ||
            d.toLowerCase().contains(detectedDistrict.toLowerCase())) {
          detectedDistrict = d;
          break;
        }
      }

      if (detectedState.isEmpty) detectedState = 'Tamil Nadu';
      if (detectedDistrict.isEmpty) detectedDistrict = 'Erode';
      if (detectedCity.isEmpty) {
        detectedCity = getDefaultCityForDistrict(detectedDistrict);
      }

      return LocationResult(
        state: detectedState,
        district: detectedDistrict,
        city: detectedCity,
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (e) {
      debugPrint('[LocationService] Error detecting location: $e');
      return null;
    }
  }
}
