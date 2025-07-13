import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeScanScreen extends StatefulWidget {
  const BarcodeScanScreen({super.key});

  @override
  State<BarcodeScanScreen> createState() => _BarcodeScanScreenState();
}

class _BarcodeScanScreenState extends State<BarcodeScanScreen> {
  bool _hasScanned = false;
  bool _flashOn = false;
  MobileScannerController controller = MobileScannerController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _toggleFlash() {
    controller.toggleTorch();
    setState(() {
      _flashOn = !_flashOn;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          MobileScanner(
            controller: controller,
            onDetect: (barcodeCapture) {
              if (_hasScanned) return;
              final code = barcodeCapture.barcodes.first.rawValue;
              if (code != null && code.isNotEmpty) {
                _hasScanned = true;
                Navigator.pop(context, code);
              }
            },
          ),
          Positioned(
            top: 40,
            left: 16,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Positioned(
            top: 40,
            right: 16,
            child: IconButton(
              icon: Icon(_flashOn ? Icons.flash_on : Icons.flash_off, color: Colors.white),
              onPressed: _toggleFlash,
            ),
          ),
          Positioned(
            bottom: 40,
            left: 16,
            child: ElevatedButton.icon(
              onPressed: () {
                // Placeholder: Implement gallery barcode detection
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text("Gallery scan coming soon.")));
              },
              icon: const Icon(Icons.image),
              label: const Text("Scan from Gallery"),
            ),
          ),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.greenAccent, width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
