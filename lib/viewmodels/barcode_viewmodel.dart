import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeViewModel extends ChangeNotifier {
  final MobileScannerController controller = MobileScannerController();
  bool _hasScanned = false;
  bool _flashOn = false;

  bool get flashOn => _flashOn;

  void toggleFlash() {
    controller.toggleTorch();
    _flashOn = !_flashOn;
    notifyListeners();
  }

  /// Returns the scanned code (or null if nothing valid)
  String? handleDetection(BarcodeCapture capture) {
    if (_hasScanned) return null;
    final code = capture.barcodes.first.rawValue;
    if (code != null && code.isNotEmpty) {
      _hasScanned = true;
      return code;
    }
    return null;
  }

  void disposeController() {
    controller.dispose();
  }
}
