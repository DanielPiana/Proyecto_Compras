import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../l10n/app_localizations.dart';

class ScanBarcodeScreen extends StatefulWidget {
  const ScanBarcodeScreen({super.key});

  @override
  State<ScanBarcodeScreen> createState() => _ScanBarcodeScreenState();
}

class _ScanBarcodeScreenState extends State<ScanBarcodeScreen> {
  late final MobileScannerController controller;
  bool _alreadyDetected = false;

  @override
  void initState() {
    super.initState();
    controller = MobileScannerController(
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.scan_barcode)),
      body: MobileScanner(
        controller: controller,
        onDetect: (capture) async {
          if (_alreadyDetected) return;

          final barcode = capture.barcodes.first.rawValue;
          if (barcode != null && mounted) {
            _alreadyDetected = true;

            await controller.stop();
            await Future.delayed(const Duration(milliseconds: 200));

            if (mounted) Navigator.pop(context, barcode);
          }
        },
      ),
    );
  }
}
