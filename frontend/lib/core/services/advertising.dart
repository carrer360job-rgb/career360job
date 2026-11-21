import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'supabase_service.dart';

class Advertising {
  static String? _userId;
  static DateTime? _checkedAt;
  static Future<Map<String, dynamic>>? _cached;
  static Future<bool>? _consent;
  static InterstitialAd? _fullScreen;
  static bool _loadingFullScreen = false;
  static final Set<String> _viewedJobs = {};

  static Future<Map<String, dynamic>> settings() async {
    const base = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'https://career360job-backend.vercel.app',
    );
    final response = await http
        .get(Uri.parse('$base/api/content/advertising'))
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) return {};
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  static Future<Map<String, dynamic>> eligibleSettings() {
    final uid = SupabaseService.client.auth.currentUser?.id;
    if (uid == null) {
      debugPrint('[AdMob] No user logged in; ads disabled.');
      return Future.value({});
    }
    if (uid != _userId ||
        _checkedAt == null ||
        DateTime.now().difference(_checkedAt!).inSeconds >= 45) {
      _userId = uid;
      _checkedAt = DateTime.now();
      _cached = () async {
        try {
          final account = await SupabaseService.client
              .from('profiles')
              .select('role,status')
              .eq('id', uid)
              .single();
          final profile = await SupabaseService.getCandidateProfile(uid);
          final age = profile?['age'];
          final role = (account['role'] ?? '').toString().toUpperCase();
          final status = (account['status'] ?? '').toString().toUpperCase();
          final isAdult = age is int ? age >= 18 : !kReleaseMode;
          debugPrint('[AdMob] Checking eligibility for $uid: role=$role, status=$status, age=$age, isAdult=$isAdult');
          if (role != 'CANDIDATE' || status != 'ACTIVE' || !isAdult) {
            debugPrint('[AdMob] User not eligible for ads (role=$role, status=$status, isAdult=$isAdult).');
            return <String, dynamic>{};
          }
          final s = await settings();
          debugPrint('[AdMob] Remote ad settings loaded: enabled=${s['enabled']}, banner=${s['banner']}, native=${s['native']}');
          return s;
        } catch (e) {
          debugPrint('[AdMob] Error checking eligible settings: $e');
          return <String, dynamic>{};
        }
      }();
    }
    return _cached!;
  }

  static Future<bool> consent() => _consent ??= _prepareConsent();
  static Future<bool> _prepareConsent() async {
    final completer = Completer<bool>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () {
        ConsentForm.loadAndShowConsentFormIfRequired((error) async {
          try {
            final allowed =
                error == null &&
                await ConsentInformation.instance.canRequestAds();
            if (allowed || !kReleaseMode) {
              await MobileAds.instance.initialize();
            }
            debugPrint('[AdMob UMP] Consent finished. Allowed: $allowed, error: $error');
            if (!completer.isCompleted) completer.complete(allowed || !kReleaseMode);
          } catch (e) {
            debugPrint('[AdMob UMP] Consent check error: $e');
            try { await MobileAds.instance.initialize(); } catch (_) {}
            if (!completer.isCompleted) completer.complete(!kReleaseMode);
          }
        });
      },
      (formError) async {
        debugPrint('[AdMob UMP] Consent info update error: ${formError.message}');
        try { await MobileAds.instance.initialize(); } catch (_) {}
        if (!completer.isCompleted) completer.complete(!kReleaseMode);
      },
    );
    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () async {
        debugPrint('[AdMob UMP] Consent timeout; initializing MobileAds directly.');
        try { await MobileAds.instance.initialize(); } catch (_) {}
        return !kReleaseMode;
      },
    );
  }

  static Future<void> preloadJobView(String jobId) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    final uid = SupabaseService.client.auth.currentUser?.id;
    if (uid != _userId) {
      _viewedJobs.clear();
      _fullScreen?.dispose();
      _fullScreen = null;
    }
    _viewedJobs.add(jobId);
    try {
      final config = await eligibleSettings();
      if (config['enabled'] != true ||
          config['interstitial'] != true ||
          _fullScreen != null ||
          _loadingFullScreen ||
          !await consent()) {
        return;
      }
      const id = kReleaseMode
          ? String.fromEnvironment(
              'ADMOB_INTERSTITIAL_ID',
              defaultValue: 'ca-app-pub-3678252568683447/6237421381',
            )
          : 'ca-app-pub-3940256099942544/1033173712';
      if (id.isEmpty) return;
      _loadingFullScreen = true;
      await InterstitialAd.load(
        adUnitId: id,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _loadingFullScreen = false;
            if (uid == SupabaseService.client.auth.currentUser?.id) {
              _fullScreen = ad;
            } else {
              ad.dispose();
            }
          },
          onAdFailedToLoad: (_) {
            _loadingFullScreen = false;
          },
        ),
      );
    } catch (_) {
      _loadingFullScreen = false;
    }
  }

  static Future<void> browsingBreak(bool Function() stillOnSearch) async {
    if (_fullScreen == null) return;
    try {
      final config = await eligibleSettings();
      if (config['enabled'] != true || config['interstitial'] != true) {
        _fullScreen?.dispose();
        _fullScreen = null;
        return;
      }
      final views = config['interstitial_views'];
      final cooldown = config['cooldown_minutes'];
      final cap = config['daily_cap'];
      if (views is! int ||
          views < 5 ||
          _viewedJobs.length < views ||
          cooldown is! int ||
          cooldown < 10 ||
          cap is! int ||
          cap < 1 ||
          cap > 2) {
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final day = '${now.year}-${now.month}-${now.day}';
      final count = prefs.getString('ad_day') == day
          ? (prefs.getInt('ad_count') ?? 0)
          : 0;
      if (count >= cap ||
          now.millisecondsSinceEpoch - (prefs.getInt('ad_last') ?? 0) <
              cooldown * 60000 ||
          !stillOnSearch()) {
        return;
      }
      final ad = _fullScreen!;
      _fullScreen = null;
      _viewedJobs.clear();
      ad.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) => ad.dispose(),
        onAdFailedToShowFullScreenContent: (ad, error) => ad.dispose(),
      );
      await prefs.setString('ad_day', day);
      await prefs.setInt('ad_count', count + 1);
      await prefs.setInt('ad_last', now.millisecondsSinceEpoch);
      if (stillOnSearch()) {
        await ad.show();
      } else {
        ad.dispose();
      }
    } catch (_) {
      _fullScreen?.dispose();
      _fullScreen = null;
    }
  }
}

class CandidateAd extends StatefulWidget {
  final bool native;
  final int jobPosition;
  const CandidateAd({super.key, this.native = false, this.jobPosition = 0});
  @override
  State<CandidateAd> createState() => _CandidateAdState();
}

class _CandidateAdState extends State<CandidateAd> with WidgetsBindingObserver {
  AdWithView? _ad;
  bool _loaded = false;
  bool _checking = false;
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => _check());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      Advertising._checkedAt = null;
      _check();
    } else {
      _clear();
    }
  }

  void _clear() {
    _ad?.dispose();
    _ad = null;
    if (mounted) setState(() => _loaded = false);
  }

  Future<void> _check() async {
    if (!mounted ||
        _checking ||
        kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    _checking = true;
    try {
      final uid = SupabaseService.client.auth.currentUser?.id;
      if (uid == null) {
        _clear();
        return;
      }
      final settings = await Advertising.eligibleSettings();
      final interval = settings['native_interval'];
      final eligible =
          settings['enabled'] == true &&
          settings[widget.native ? 'native' : 'banner'] == true &&
          (!widget.native ||
              (interval is int &&
                  interval >= 5 &&
                  interval <= 12 &&
                  widget.jobPosition % interval == 0 &&
                  widget.jobPosition ~/ interval <= 3));
      if (!eligible) {
        debugPrint('[AdMob] Ad placement (native: ${widget.native}, pos: ${widget.jobPosition}) is not eligible under settings (enabled: ${settings['enabled']}).');
        _clear();
        return;
      }
      final hasConsent = await Advertising.consent();
      if (!mounted) return;
      if (!(ModalRoute.of(context)?.isCurrent ?? false) ||
          _ad != null ||
          !hasConsent ||
          uid != SupabaseService.client.auth.currentUser?.id) {
        debugPrint('[AdMob] Pre-load check stopped: mounted=$mounted, isCurrent=${ModalRoute.of(context)?.isCurrent}, adExists=${_ad != null}, consent=$hasConsent');
        return;
      }
      final id = widget.native
          ? (kReleaseMode
                ? const String.fromEnvironment(
                    'ADMOB_NATIVE_ID',
                    defaultValue: 'ca-app-pub-3678252568683447/7176144717',
                  )
                : 'ca-app-pub-3940256099942544/2247696110')
          : (kReleaseMode
                ? const String.fromEnvironment(
                    'ADMOB_BANNER_ID',
                    defaultValue: 'ca-app-pub-3678252568683447/4579182791',
                  )
                : 'ca-app-pub-3940256099942544/6300978111');
      if (id.isEmpty) return;
      debugPrint('[AdMob] Requesting ${widget.native ? "Native" : "Banner"} ad with ID: $id');
      if (widget.native) {
        _ad = NativeAd(
          adUnitId: id,
          request: const AdRequest(),
          nativeTemplateStyle: NativeTemplateStyle(
            templateType: TemplateType.small,
          ),
          listener: NativeAdListener(
            onAdLoaded: (ad) {
              debugPrint('[AdMob Native] Loaded successfully!');
              if (mounted && identical(_ad, ad)) {
                setState(() => _loaded = true);
              } else {
                ad.dispose();
              }
            },
            onAdFailedToLoad: (ad, error) {
              debugPrint('[AdMob Native] Failed to load: ${error.message} (code: ${error.code})');
              ad.dispose();
              if (identical(_ad, ad)) _ad = null;
            },
          ),
        );
      } else {
        final size = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(
          (MediaQuery.sizeOf(context).width - 48).floor(),
        );
        if (size == null || !mounted) return;
        _ad = BannerAd(
          adUnitId: id,
          size: size,
          request: const AdRequest(),
          listener: BannerAdListener(
            onAdLoaded: (ad) {
              debugPrint('[AdMob Banner] Loaded successfully!');
              if (mounted && identical(_ad, ad)) {
                setState(() => _loaded = true);
              } else {
                ad.dispose();
              }
            },
            onAdFailedToLoad: (ad, error) {
              debugPrint('[AdMob Banner] Failed to load: ${error.message} (code: ${error.code})');
              ad.dispose();
              if (identical(_ad, ad)) _ad = null;
            },
          ),
        );
      }
      await _ad!.load();
    } catch (e) {
      debugPrint('[AdMob] Error checking or loading ad: $e');
      _clear();
      _clear();
    } finally {
      _checking = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => !_loaded || _ad == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            children: [
              const Text(
                'Advertisement',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: widget.native
                    ? double.infinity
                    : (_ad as BannerAd).size.width.toDouble(),
                height: widget.native
                    ? 140
                    : (_ad as BannerAd).size.height.toDouble(),
                child: AdWidget(ad: _ad!),
              ),
            ],
          ),
        );
}

class AdvertisingPrivacyButton extends StatelessWidget {
  const AdvertisingPrivacyButton({super.key});
  @override
  Widget build(BuildContext context) =>
      kIsWeb || defaultTargetPlatform != TargetPlatform.android
      ? const SizedBox.shrink()
      : TextButton(
          onPressed: () async {
            final status = await ConsentInformation.instance
                .getPrivacyOptionsRequirementStatus();
            if (status == PrivacyOptionsRequirementStatus.required) {
              await ConsentForm.showPrivacyOptionsForm((_) {
                Advertising._consent = null;
              });
            } else if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'No additional advertising privacy choices are required for your region.',
                  ),
                ),
              );
            }
          },
          child: const Text('Advertising privacy choices'),
        );
}
