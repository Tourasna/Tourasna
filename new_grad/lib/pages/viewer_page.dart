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
  late final WebViewController controller;
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    final url = widget.place.infoJson?['glb_url'] ?? widget.place.glbUrl ?? '';

    print("VIEWER → Initializing with URL = $url");

    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            print("VIEWER → Page finished loading");
          },
        ),
      )
      ..addJavaScriptChannel(
        'ModelViewer',
        onMessageReceived: (JavaScriptMessage message) {
          print("VIEWER → JS Message: ${message.message}");

          if (message.message.startsWith('loaded')) {
            setState(() {
              isLoading = false;
              errorMessage = null;
            });
          } else if (message.message.startsWith('error:')) {
            setState(() {
              isLoading = false;
              errorMessage = message.message.replaceFirst('error:', '').trim();
            });
          } else if (message.message.startsWith('progress:')) {}
        },
      )
      ..loadHtmlString(_buildHtml(url));
  }

  String _buildHtml(String modelUrl) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta charset="UTF-8">
  <script type="module" src="https://ajax.googleapis.com/ajax/libs/model-viewer/3.5.0/model-viewer.min.js"></script>
  <style>
    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
    }
    
    html, body {
      width: 100%;
      height: 100%;
      overflow: hidden;
      background: #1a1a1a;
    }
    
    model-viewer {
      width: 100%;
      height: 100%;
      display: block;
    }
    
    #status {
      position: absolute;
      top: 50%;
      left: 50%;
      transform: translate(-50%, -50%);
      color: white;
      font-family: Arial, sans-serif;
      text-align: center;
      z-index: 1000;
      padding: 20px;
      background: rgba(0,0,0,0.7);
      border-radius: 8px;
    }
  </style>
</head>
<body>
  <div id="status">Initializing...</div>
  
  <model-viewer 
    src="$modelUrl"
    alt="${widget.place.name}"
    camera-controls
    touch-action="pan-y"
    auto-rotate
    shadow-intensity="1"
    environment-image="neutral"
    exposure="1">
  </model-viewer>
  
  <script>
    const modelViewer = document.querySelector('model-viewer');
    const status = document.getElementById('status');
    
    console.log('Attempting to load model from: $modelUrl');
    status.textContent = 'Loading model...';
    
    modelViewer.addEventListener('load', () => {
      console.log('✓ Model loaded successfully');
      status.style.display = 'none';
      ModelViewer.postMessage('loaded');
    });
    
    modelViewer.addEventListener('error', (event) => {
      console.error('✗ Model load error:', event);
      
      let errorMsg = 'Unknown error';
      
      if (event.detail) {
        if (event.detail.type) errorMsg = event.detail.type;
        if (event.detail.message) errorMsg = event.detail.message;
      }
      
      // Check for common issues
      fetch('$modelUrl', { method: 'HEAD' })
        .then(response => {
          if (!response.ok) {
            errorMsg = 'HTTP ' + response.status + ': ' + response.statusText;
          }
          console.error('Fetch test result:', response.status, response.statusText);
        })
        .catch(fetchError => {
          errorMsg = 'Network error: ' + fetchError.message;
          console.error('Fetch test failed:', fetchError);
        })
        .finally(() => {
          status.textContent = 'Error: ' + errorMsg;
          status.style.color = '#ff4444';
          ModelViewer.postMessage('error: ' + errorMsg);
        });
    });
    
    modelViewer.addEventListener('progress', (event) => {
      const progress = Math.round(event.detail.totalProgress * 100);
      status.textContent = 'Loading: ' + progress + '%';
      console.log('Loading progress:', progress + '%');
      ModelViewer.postMessage('progress: ' + progress);
    });
    
    // Timeout fallback
    setTimeout(() => {
      if (status.style.display !== 'none') {
        console.error('Load timeout after 30 seconds');
        status.textContent = 'Loading timeout - model may be too large';
        status.style.color = '#ffaa00';
        ModelViewer.postMessage('error: timeout');
      }
    }, 30000);
  </script>
</body>
</html>
    ''';
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.place.infoJson?['glb_url'] ?? widget.place.glbUrl ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.place.name),
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                isLoading = true;
                errorMessage = null;
              });
              controller.loadHtmlString(_buildHtml(url));
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: controller),

          if (isLoading && errorMessage == null)
            Container(
              color: Colors.black,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Loading 3D Model...',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),

          if (errorMessage != null)
            Container(
              color: Colors.black,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 64,
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
                        errorMessage!,
                        style: const TextStyle(color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            isLoading = true;
                            errorMessage = null;
                          });
                          controller.loadHtmlString(_buildHtml(url));
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
