import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../models/place.dart';

class ViewerPage extends StatefulWidget {
  final Place place;

  const ViewerPage({super.key, required this.place});

  @override
  State<ViewerPage> createState() => _ViewerPageState();
}

class _ViewerPageState extends State<ViewerPage> {
  late final WebViewController _controller;

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();

    final String? glbUrl = widget.place.glbUrl;

    if (glbUrl == null || glbUrl.isEmpty) {
      _error = 'No 3D model available for this place';
      _loading = false;
      return;
    }

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..addJavaScriptChannel(
        'Viewer',
        onMessageReceived: (JavaScriptMessage message) {
          if (message.message == 'loaded') {
            setState(() {
              _loading = false;
              _error = null;
            });
          } else if (message.message.startsWith('error:')) {
            setState(() {
              _loading = false;
              _error = message.message.replaceFirst('error:', '').trim();
            });
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            // Inject model URL AFTER HTML is fully loaded
            _controller.runJavaScript("setModel('${Uri.encodeFull(glbUrl)}');");
          },
        ),
      )
      ..loadFlutterAsset('assets/html/3d_viewer.html');
  }

  void _reload() {
    if (!_loading && _error == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    _controller.reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.place.name),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _reload),
        ],
      ),
      body: Stack(
        children: [
          if (_error == null) WebViewWidget(controller: _controller),

          if (_loading && _error == null)
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text(
                    'Loading 3D model...',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),

          if (_error != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Failed to load 3D model',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: const TextStyle(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _reload,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
