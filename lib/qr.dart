import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:prompt_dialog/prompt_dialog.dart';

import 'package:xl_otpsend/scanresult.dart';

class QRViewExample extends StatefulWidget {
  const QRViewExample({super.key});

  @override
  State<QRViewExample> createState() => _QRViewExampleState();
}

class _QRViewExampleState extends State<QRViewExample>
    with WidgetsBindingObserver {
  /// A single controller drives both the preview and the scan-window overlay,
  /// and lets us switch cameras. Because we pass it in ourselves (rather than
  /// letting [MobileScanner] create one), the widget does not manage its
  /// lifecycle or dispose it for us: that is handled below.
  final MobileScannerController controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  /// The barcode stream can emit several times before the pop completes, so
  /// guard against popping the route more than once.
  bool _hasResult = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!controller.value.hasCameraPermission) {
      return;
    }

    switch (state) {
      case AppLifecycleState.resumed:
        unawaited(controller.start());
      case AppLifecycleState.inactive:
        unawaited(controller.stop());
      // detached/hidden/paused need no action.
      default:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasResult) {
      return;
    }

    final String? code = capture.barcodes.firstOrNull?.rawValue;

    if (code == null || code.isEmpty) {
      return;
    }

    _hasResult = true;
    debugPrint('Scanned! $code');
    Navigator.pop(context, ScanResult.uri(code));
  }

  Future<void> _enterManually() async {
    final result = await prompt(
      context,
      title: const Text('Please enter the provided secret.'),
      textOK: const Text('OK'),
      textCancel: const Text('Cancel'),
      maxLines: 1,
      minLines: 1,
      autoFocus: true,
      textCapitalization: TextCapitalization.characters,
    );

    if (result == null || !mounted) {
      return;
    }

    debugPrint('Manual entry: $result');
    Navigator.pop(context, ScanResult.raw(result));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: <Widget>[
          Expanded(flex: 4, child: _buildQrView(context)),
          Expanded(
            flex: 1,
            child: FittedBox(
              fit: BoxFit.contain,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Container(
                        margin: const EdgeInsets.all(8),
                        child: ElevatedButton(
                          onPressed: _enterManually,
                          child: const Text('Enter by hand'),
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.all(8),
                        child: ElevatedButton(
                          onPressed: () => controller.switchCamera(),
                          child: const Icon(Icons.flip_camera_ios),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQrView(BuildContext context) {
    // Keep the old qr_code_scanner behaviour of a smaller cut-out on small
    // screens. mobile_scanner has no overlay-shape widget, so the scan window
    // is computed here and used for both detection and the overlay.
    final double scanArea =
        (MediaQuery.of(context).size.width < 400 ||
            MediaQuery.of(context).size.height < 400)
        ? 150.0
        : 300.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final Size size = constraints.biggest;
        final Rect scanWindow = Rect.fromCenter(
          center: Offset(size.width / 2, size.height / 2),
          width: scanArea,
          height: scanArea,
        );

        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            MobileScanner(
              controller: controller,
              scanWindow: scanWindow,
              onDetect: _onDetect,
            ),
            ScanWindowOverlay(
              controller: controller,
              scanWindow: scanWindow,
              borderColor: Colors.red,
              borderRadius: BorderRadius.circular(10),
              borderWidth: 10,
            ),
          ],
        );
      },
    );
  }
}
