import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MobileAds.instance.initialize();
  runApp(const DuckShooterApp());
}

class DuckShooterApp extends StatelessWidget {
  const DuckShooterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Duck Shooter 2',
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFF0C0502),
      ),
      home: const DuckGameScreen(),
    );
  }
}

class DuckGameScreen extends StatefulWidget {
  const DuckGameScreen({super.key});

  @override
  State<DuckGameScreen> createState() => _DuckGameScreenState();
}

class _DuckGameScreenState extends State<DuckGameScreen> {
  final String bannerAdUnitId = 'ca-app-pub-1590363558146928/9630631281';
  final String interstitialAdUnitId = 'ca-app-pub-1590363558146928/7196039630';
  final String rewardedAdUnitId = 'ca-app-pub-1590363558146928/2274885449';

  late final WebViewController _webController;
  BannerAd? _bannerAd;
  bool _isBannerLoaded = false;
  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;
  bool _isRewardedLoading = false;

  @override
  void initState() {
    super.initState();
    _initBanner();
    _loadInterstitial();
    _loadRewarded();
    _setupWebView();
  }

  void _initBanner() {
    _bannerAd = BannerAd(
      adUnitId: bannerAdUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (_) => setState(() => _isBannerLoaded = true),
        onAdFailedToLoad: (ad, err) => ad.dispose(),
      ),
    )..load();
  }

  void _loadInterstitial() {
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitialAd = ad,
        onAdFailedToLoad: (err) => _interstitialAd = null,
      ),
    );
  }

  void _showInterstitial() {
    if (_interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _loadInterstitial();
        },
        onAdFailedToShowFullScreenContent: (ad, err) {
          ad.dispose();
          _loadInterstitial();
        },
      );
      _interstitialAd!.show();
      _interstitialAd = null;
    } else {
      _loadInterstitial();
    }
  }

  void _loadRewarded() {
    if (_isRewardedLoading || _rewardedAd != null) return;
    _isRewardedLoading = true;
    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isRewardedLoading = false;
        },
        onAdFailedToLoad: (err) {
          _rewardedAd = null;
          _isRewardedLoading = false;
        },
      ),
    );
  }

  void _showRewarded() {
    if (_rewardedAd != null) {
      _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _rewardedAd = null;
          _loadRewarded();
        },
        onAdFailedToShowFullScreenContent: (ad, err) {
          ad.dispose();
          _rewardedAd = null;
          _loadRewarded();
        },
      );
      _rewardedAd!.show(onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
        _webController.runJavaScript('window.onRewardedAdReward();');
      });
      _rewardedAd = null;
    } else {
      _loadRewarded();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ad load ho raha hai, kripya 2 second baad dobara tap karein!'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _setupWebView() {
    _webController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0C0502))
      ..addJavaScriptChannel(
        'AdMobBridge',
        onMessageReceived: (JavaScriptMessage message) {
          if (message.message == 'showInterstitial') {
            _showInterstitial();
          } else if (message.message == 'showRewarded') {
            _showRewarded();
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) async {
            final url = request.url;
            if (url.contains('youtube.com') ||
                url.contains('youtu.be') ||
                url.startsWith('intent://')) {
              final uri = Uri.parse(url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadFlutterAsset('assets/index.html');
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (await _webController.canGoBack()) {
          _webController.goBack();
          return false;
        }
        return true;
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: WebViewWidget(controller: _webController),
              ),
              if (_isBannerLoaded && _bannerAd != null)
                SizedBox(
                  width: _bannerAd!.size.width.toDouble(),
                  height: _bannerAd!.size.height.toDouble(),
                  child: AdWidget(ad: _bannerAd!),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
