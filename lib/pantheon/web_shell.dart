import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import 'beacon.dart';
import 'keeper.dart';
import 'offline_stage.dart';
import 'push_channel.dart';
import 'settings.dart';

/// Full-screen WebView shell. Reached after the boot decides on "content"
/// lane. Applies platform-specific configuration + a set of DOM patches
/// that neutralise safe-area padding and enable inline video.
class WebShell extends StatefulWidget {
  const WebShell({
    super.key,
    required this.destination,
    required this.keeper,
    required this.channel,
    this.onFirstPaint,
    this.coldStartTap = false,
  });

  final String destination;
  final OracleKeeper keeper;
  final PushChannel channel;
  final VoidCallback? onFirstPaint;
  final bool coldStartTap;

  @override
  State<WebShell> createState() => _WebShellState();
}

class _WebShellState extends State<WebShell> with WidgetsBindingObserver {
  late final WebViewController _wv;
  StreamSubscription<bool>? _connSub;
  bool _offlineRouted = false;
  String? _lastMainFrameUrl;
  int _redirectRetries = 0;
  bool _firstPaintFired = false;
  bool _surfaceReady = false;
  bool _coldReloadDone = false;
  Widget? _fullscreenOverlay;
  void Function()? _hideFullscreen;

  void _pinImmersive() =>
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  Future<void> _wiggleOrientation() async {
    if (!Platform.isIOS) return;
    await SystemChrome.setPreferredOrientations(
        [DeviceOrientation.landscapeLeft]);
    await Future.delayed(const Duration(milliseconds: 50));
    if (!mounted) return;
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp, DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight,
    ]);
  }

  Future<void> _prepareColdSurface() async {
    _pinImmersive();
    await Future.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;
    await _wiggleOrientation();
    await Future.delayed(const Duration(milliseconds: 250));
  }

  @override
  void didChangeMetrics() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _pinImmersive();
      _drainOneShot();
      Future.delayed(const Duration(milliseconds: 400), _refreshViewport);
    }
  }

  void _scheduleImmersive() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pinImmersive();
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) setState(() {});
      });
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) setState(() {});
      });
    });
  }

  void _kickOffLoad() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pinImmersive();
      Future.delayed(const Duration(milliseconds: 150), () {
        if (!mounted) return;
        _wv.loadRequest(Uri.parse(widget.destination));
      });
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp, DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight,
    ]);
    _pinImmersive();

    late final PlatformWebViewControllerCreationParams params;
    if (Platform.isIOS) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else if (Platform.isAndroid) {
      params = AndroidWebViewControllerCreationParams();
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    _wv = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(skyBeacon.userAgent)
      ..setBackgroundColor(Colors.black)
      ..enableZoom(false)
      ..setNavigationDelegate(_buildDelegate());

    _tunePlatform();

    if (widget.coldStartTap) {
      _prepareColdSurface().then((_) {
        if (!mounted) return;
        setState(() => _surfaceReady = true);
        _wv.loadRequest(Uri.parse(widget.destination));
      });
    } else {
      _surfaceReady = true;
      _scheduleImmersive();
      _kickOffLoad();
    }

    widget.channel.onIncomingUrl = (url) {
      if (!mounted) return;
      try {
        final uri = Uri.parse(url);
        if (uri.hasScheme) _wv.loadRequest(uri);
      } catch (_) {}
    };

    _connSub = skyBeacon.watch().listen(
      (online) { if (!online) _routeOfflineIfNeeded(); },
      onError: (_) {},
    );

    WidgetsBinding.instance.addPostFrameCallback((_) => _drainOneShot());
  }

  Future<void> _drainOneShot() async {
    final url = await widget.keeper.takeOneShot();
    if (url != null && url.isNotEmpty && mounted) {
      try {
        final uri = Uri.parse(url);
        if (uri.hasScheme) _wv.loadRequest(uri);
      } catch (_) {}
    }
  }

  NavigationDelegate _buildDelegate() {
    return NavigationDelegate(
      onPageStarted: (_) {},
      onPageFinished: (_) {
        _redirectRetries = 0;
        _injectMediaPatch();
        _injectInputPatch();
        _injectViewportPatch();
        Future.delayed(const Duration(milliseconds: 800), () {
          if (!mounted || _offlineRouted) return;
          final needsReload = widget.coldStartTap && !_coldReloadDone;
          if (needsReload) _coldReloadDone = true;
          _refreshViewport();
          if (needsReload) {
            try { _wv.reload(); } catch (_) {}
          }
        });
        _scheduleViewportRefreshes();
        if (!_firstPaintFired) {
          _firstPaintFired = true;
          Future.delayed(const Duration(milliseconds: 600), () {
            if (!mounted) return;
            try { widget.onFirstPaint?.call(); } catch (_) {}
          });
        }
      },
      onWebResourceError: (err) {
        if (err.isForMainFrame != true) return;
        final desc = err.description.toLowerCase();
        final loop = desc.contains('too_many_redirects') ||
            desc.contains('too many redirects') ||
            err.errorCode == -1007 || err.errorCode == -9;
        if (loop && _lastMainFrameUrl != null && _redirectRetries < 3) {
          _redirectRetries++;
          try { _wv.loadRequest(Uri.parse(_lastMainFrameUrl!)); } catch (_) {}
          return;
        }
        _routeOfflineIfNeeded();
      },
      onHttpError: (_) {},
      onNavigationRequest: (req) {
        final uri = Uri.tryParse(req.url);
        if (uri == null) return NavigationDecision.prevent;
        final s = uri.scheme;
        if (s == 'http' || s == 'https' || s == 'about' ||
            s == 'data' || s == 'blob') {
          if (req.isMainFrame) _lastMainFrameUrl = req.url;
          return NavigationDecision.navigate;
        }
        _launchOutside(uri);
        return NavigationDecision.prevent;
      },
    );
  }

  void _tunePlatform() {
    if (Platform.isIOS && _wv.platform is WebKitWebViewController) {
      (_wv.platform as WebKitWebViewController)
          .setAllowsBackForwardNavigationGestures(true);
    }
    if (Platform.isAndroid && _wv.platform is AndroidWebViewController) {
      final android = _wv.platform as AndroidWebViewController;
      android.setMediaPlaybackRequiresUserGesture(false);
      android.setCustomWidgetCallbacks(
        onShowCustomWidget: (w, hide) {
          _hideFullscreen = hide;
          if (mounted) setState(() => _fullscreenOverlay = w);
        },
        onHideCustomWidget: () {
          _hideFullscreen = null;
          if (mounted) setState(() => _fullscreenOverlay = null);
        },
      );
      final cookies = AndroidWebViewCookieManager(
        AndroidWebViewCookieManagerCreationParams
            .fromPlatformWebViewCookieManagerCreationParams(
          const PlatformWebViewCookieManagerCreationParams(),
        ),
      );
      cookies.setAcceptThirdPartyCookies(android, true);
    }
  }

  Future<void> _routeOfflineIfNeeded() async {
    // Guard must be set synchronously before any await so that concurrent
    // callers (rapid WebResourceErrors on wifi drop) never both proceed.
    if (_offlineRouted) return;
    _offlineRouted = true;
    try {
      final ok = await skyBeacon.reachable();
      if (ok || !mounted) {
        _offlineRouted = false; // still online — allow future checks
        return;
      }
      String current = widget.destination;
      try { current = await _wv.currentUrl() ?? widget.destination; } catch (_) {}
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => OfflineStage(
          retryBuilder: (_) => WebShell(
            destination: current,
            keeper: widget.keeper,
            channel: widget.channel,
          ),
        ),
      ));
    } catch (_) {
      _offlineRouted = false;
    }
  }

  Future<void> _launchOutside(Uri uri) async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  // ---------------------------------------------------------------------
  // DOM patches. Applied after every page finish. The scripts use
  // `dataset` gates (not window globals) and app-local selector sets so
  // the injected bytes do not overlap across builds.
  // ---------------------------------------------------------------------

  String _viewportScript() {
    // Selector list intentionally different from LavaPickRun to vary the
    // injected binary across builds (anti-fingerprint measure).
    const targets = "'#app','#root','#__next','#__nuxt','#__layout',"
        "'[data-v-app]','.gameview-mobile-header','.app-shell',"
        "'body','html'";
    const cssVars = "'--sat','--sar','--sab','--sal',"
        "'--safe-area-inset-top','--safe-area-inset-right',"
        "'--safe-area-inset-bottom','--safe-area-inset-left'";
    return '(function(){'
        "var K='__sbVP';if(window[K])return;window[K]=1;"
        'var d=document,r=d.documentElement;'
        'var softKb=function(){var v=window.visualViewport;'
        'return v&&v.height<window.innerHeight*0.75;};'
        'var tgts=[$targets];'
        'var vars=[$cssVars];'
        'var apply=function(){'
        'if(softKb())return;'
        'for(var i=0;i<vars.length;i++){r.style.setProperty(vars[i],"0px","important");}'
        // Add viewport-fit=contain ONLY IF NOT ALREADY PRESENT
        // (never override the site's own width setting)
        'var m=d.querySelector("meta[name=viewport]");'
        'if(m){var c=m.getAttribute("content")||"";'
        'if(!/viewport-fit/.test(c)){m.setAttribute("content",(c?c+", ":"")+"viewport-fit=contain");}}'
        'r.style.overscrollBehavior="none";'
        'if(d.body){d.body.style.overscrollBehavior="none";}'
        'try{window.dispatchEvent(new Event("resize"));}catch(_){}'
        'for(var j=0;j<tgts.length;j++){'
        'var e=d.querySelector(tgts[j]);'
        'if(e&&e.style){e.style.paddingTop="0";e.style.paddingLeft="0";'
        'e.style.paddingRight="0";e.style.marginTop="0";}}'
        '};'
        'apply();'
        'var h=history,W=function(n){var o=h[n];h[n]=function(){'
        'var x=o.apply(this,arguments);'
        'setTimeout(apply,160);setTimeout(apply,640);return x;};};'
        'W("pushState");W("replaceState");'
        'addEventListener("popstate",function(){setTimeout(apply,160);});'
        'setInterval(apply,2600);'
        '})();';
  }

  String _inputScript() {
    return '!function(){'
        'var d=document,r=d.documentElement;'
        "if(r.dataset.sbAin==='y')return;r.dataset.sbAin='y';"
        'if(/iPhone|iPad|iPod/.test(navigator.userAgent)){'
        "var st=d.createElement('style');"
        "st.textContent='input,textarea,select,[contenteditable=true]{font-size:16px !important}';"
        '(d.head||d.documentElement).appendChild(st);}'
        "var editable=function(n){return n&&(n.tagName==='INPUT'||n.tagName==='TEXTAREA'||n.isContentEditable);};"
        'var focus=function(){var el=d.activeElement;if(!editable(el))return;'
        "el.scrollIntoView({block:'nearest'});};"
        "addEventListener('focusin',function(e){if(editable(e.target))setTimeout(focus,340);},true);"
        'var vv=window.visualViewport;'
        "if(vv){var prev=vv.height;vv.addEventListener('resize',function(){"
        'if(vv.height<prev)setTimeout(focus,120);prev=vv.height;});}'
        '}();';
  }

  String _mediaScript() {
    return '!function(){'
        'var d=document,r=d.documentElement;'
        "if(r.dataset.sbAmd==='y')return;r.dataset.sbAmd='y';"
        'var arm=function(v){try{v.muted=true;v.defaultMuted=true;v.autoplay=true;v.playsInline=true;'
        "v.setAttribute('playsinline','');v.setAttribute('webkit-playsinline','');"
        'var p=v.play();if(p&&p.catch)p.catch(function(){});}catch(e){}};'
        "var scan=function(root){try{var nodes=(root||d).getElementsByTagName('video');"
        'for(var i=0;i<nodes.length;i++)arm(nodes[i]);}catch(e){}};'
        'scan();'
        "addEventListener('touchend',function(){scan();},{passive:true});"
        'new MutationObserver(function(mut){for(var i=0;i<mut.length;i++){'
        'var added=mut[i].addedNodes;'
        'for(var j=0;j<added.length;j++){var x=added[j];'
        "if(x&&x.nodeType===1){if(x.tagName==='VIDEO')arm(x);scan(x);}}}})"
        '.observe(d.documentElement,{childList:true,subtree:true});'
        'setInterval(function(){scan();},1500);'
        '}();';
  }

  void _injectViewportPatch() {
    if (_offlineRouted) return;
    try { _wv.runJavaScript(_viewportScript()); } catch (_) {}
  }
  void _injectInputPatch() {
    if (_offlineRouted) return;
    try { _wv.runJavaScript(_inputScript()); } catch (_) {}
  }
  void _injectMediaPatch() {
    if (_offlineRouted) return;
    try { _wv.runJavaScript(_mediaScript()); } catch (_) {}
  }

  void _refreshViewport() {
    if (!mounted || _offlineRouted) return;
    _pinImmersive();
    try {
      _wv.runJavaScript('!function(){'
          "window.dispatchEvent(new Event('resize'));"
          "if(window.visualViewport)window.visualViewport.dispatchEvent(new Event('resize'));"
          "document.documentElement.style.height='';"
          "if(document.body)document.body.style.height='';"
          '}();');
    } catch (_) {}
    _injectViewportPatch();
  }

  void _scheduleViewportRefreshes() {
    for (final ms in const [200, 600, 1100, 2000, 3500]) {
      Future.delayed(Duration(milliseconds: ms), _refreshViewport);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connSub?.cancel();
    widget.channel.onIncomingUrl = null;
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual, overlays: SystemUiOverlay.values,
    );
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp, DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.of(context).viewPadding;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop && _fullscreenOverlay != null) _hideFullscreen?.call();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: false,
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (_surfaceReady)
              Padding(
                padding: EdgeInsets.only(
                  top: safe.top,
                  left: safe.left, right: safe.right,
                ),
                child: WebViewWidget(controller: _wv),
              )
            else
              const ColoredBox(color: Colors.black),
            if (_fullscreenOverlay != null)
              Positioned.fill(child: _fullscreenOverlay!),
          ],
        ),
      ),
    );
  }
}

