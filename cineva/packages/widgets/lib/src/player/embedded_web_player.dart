
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class CinevaEmbeddedWebPlayer extends StatefulWidget {
  const CinevaEmbeddedWebPlayer({super.key, required this.url});

  final String url;

  @override
  State<CinevaEmbeddedWebPlayer> createState() => _CinevaEmbeddedWebPlayerState();
}

class _CinevaEmbeddedWebPlayerState extends State<CinevaEmbeddedWebPlayer> {
  InAppWebViewController? _controller;
  bool _loading = true;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(widget.url)),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              mediaPlaybackRequiresUserGesture: false,
              allowsInlineMediaPlayback: true,
              useShouldOverrideUrlLoading: false,
              transparentBackground: false,
              backgroundColor: Colors.black,
              supportZoom: false,
            ),
            onWebViewCreated: (controller) => _controller = controller,
            onLoadStart: (_, __) => mounted ? setState(() => _loading = true) : null,
            onLoadStop: (_, __) => mounted ? setState(() {
              _loading = false;
              _error = null;
            }) : null,
            onReceivedError: (_, request, error) {
              if (request.isForMainFrame == true && mounted) {
                setState(() {
                  _loading = false;
                  _error = error.description;
                });
              }
            },
            onReceivedHttpError: (_, request, errorResponse) {
              if (request.isForMainFrame == true && mounted && errorResponse.statusCode != null && errorResponse.statusCode! >= 400) {
                setState(() {
                  _loading = false;
                  _error = 'Le fournisseur a retourné HTTP ${errorResponse.statusCode}.';
                });
              }
            },
          ),
          if (_loading)
            const Center(child: CircularProgressIndicator()),
          if (_error != null)
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Card(
                  color: const Color(0xFF171717),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.language_rounded, size: 42, color: Colors.white70),
                        const SizedBox(height: 12),
                        const Text(
                          'Lecteur web indisponible',
                          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white60),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: () async {
                            setState(() {
                              _error = null;
                              _loading = true;
                            });
                            await _controller?.reload();
                          },
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Réessayer'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
