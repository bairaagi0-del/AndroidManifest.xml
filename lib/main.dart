import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MobileAds.instance.initialize();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: DuckShooterGame(),
  ));
}

class DuckShooterGame extends StatefulWidget {
  const DuckShooterGame({super.key});

  @override
  State<DuckShooterGame> createState() => _DuckShooterGameState();
}

class _DuckShooterGameState extends State<DuckShooterGame> {
  late final WebViewController _controller;
  RewardedAd? _rewardedAd;
  InterstitialAd? _interstitialAd;

  @override
  void initState() {
    super.initState();
    _loadInterstitialAd();
    _loadRewardedAd();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..clearCache() // FORCE CACHE CLEAR
      ..clearLocalStorage()
      ..setBackgroundColor(const Color(0xFF0C0502))
      ..addJavaScriptChannel(
        'AdMobBridge',
        onMessageReceived: (JavaScriptMessage message) {
          if (message.message == 'showInterstitial') {
            _showInterstitialAd();
          } else if (message.message == 'showRewarded') {
            _showRewardedAd();
          }
        },
      )
      ..loadFlutterAsset('assets/index.html');
  }

  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: 'ca-app-pub-1590363558146928/8937070118',
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitialAd = ad,
        onAdFailedToLoad: (error) => _interstitialAd = null,
      ),
    );
  }

  void _showInterstitialAd() {
    if (_interstitialAd != null) {
      _interstitialAd!.show();
      _loadInterstitialAd();
    }
  }

  void _loadRewardedAd() {
    RewardedAd.load(
      adUnitId: 'ca-app-pub-1590363558146928/6265005825',
      request: const AdRequest(),
      adLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => _rewardedAd = ad,
        onAdFailedToLoad: (error) => _rewardedAd = null,
      ),
    );
  }

  void _showRewardedAd() {
    if (_rewardedAd != null) {
      _rewardedAd!.show(onUserEarnedReward: (ad, reward) {
        _controller.runJavaScript('window.onRewardedAdReward();');
      });
      _loadRewardedAd();
    } else {
      _controller.runJavaScript('window.onAdLoadFailed();');
      _loadRewardedAd();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0502),
      body: SafeArea(
        child: WebViewWidget(controller: _controller),
      ),
    );
  }
}
