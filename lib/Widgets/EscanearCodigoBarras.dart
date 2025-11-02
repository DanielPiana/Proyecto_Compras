import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class EscanearCodigoScreen extends StatefulWidget {
  const EscanearCodigoScreen({super.key});

  @override
  State<EscanearCodigoScreen> createState() => _EscanearCodigoScreenState();
}

class _EscanearCodigoScreenState extends State<EscanearCodigoScreen> {
  late final MobileScannerController controller;
  bool _yaDetectado = false;

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
      appBar: AppBar(title: const Text("Escanear código")),
      body: MobileScanner(
        controller: controller,
        onDetect: (capture) async {
          if (_yaDetectado) return;

          final barcode = capture.barcodes.first.rawValue;
          if (barcode != null && mounted) {
            _yaDetectado = true;

            await controller.stop();
            await Future.delayed(const Duration(milliseconds: 200));

            if (mounted) Navigator.pop(context, barcode);
          }
        },
      ),
    );
  }
}
