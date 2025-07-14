import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/barcode_viewmodel.dart';

class BarcodeScanScreen extends StatelessWidget {
  const BarcodeScanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => BarcodeViewModel(),
      builder: (context, _) {
        final vm = context.watch<BarcodeViewModel>();
        return Scaffold(
          body: Stack(
            children: [
              MobileScanner(
                controller: vm.controller,
                onDetect: (barcodeCapture) {
                  final code = vm.handleDetection(barcodeCapture);
                  if (code != null) {
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
                  icon: Icon(vm.flashOn ? Icons.flash_on : Icons.flash_off, color: Colors.white),
                  onPressed: vm.toggleFlash,
                ),
              ),
              Positioned(
                bottom: 40,
                left: 16,
                child: ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Gallery scan coming soon.")),
                    );
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
      },
    );
  }
}
