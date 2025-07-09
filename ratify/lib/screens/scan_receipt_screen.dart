import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:image_picker/image_picker.dart';

class ScanReceiptScreen extends StatefulWidget {
  const ScanReceiptScreen({super.key});

  @override
  State<ScanReceiptScreen> createState() => _ScanReceiptScreenState();
}

class _ScanReceiptScreenState extends State<ScanReceiptScreen> {
  File? _image;
  String _extractedText = '';
  double? _parsedTotal;
  final TextEditingController _textController = TextEditingController();
  bool _scanning = false;

  Future<void> _pickImage(ImageSource source) async {
    final picked = await ImagePicker().pickImage(source: source);
    if (picked == null) return;

    setState(() {
      _image = File(picked.path);
      _scanning = true;
      _extractedText = '';
      _parsedTotal = null;
    });

    final inputImage = InputImage.fromFile(_image!);
    final textRecognizer = GoogleMlKit.vision.textRecognizer();
    final RecognizedText recognizedText =
        await textRecognizer.processImage(inputImage);
    await textRecognizer.close();

    final rawText = recognizedText.text;
    final total = extractTotalFromText(rawText);

    setState(() {
      _extractedText = rawText;
      _textController.text = rawText;
      _parsedTotal = total;
      _scanning = false;
    });
  }

  double? extractTotalFromText(String rawText) {
    final lines = rawText
        .split('\n')
        .map((line) => line.trim().toLowerCase())
        .where((line) => line.isNotEmpty)
        .toList();

    final keywords = ['total', 'importe', 'amount', 'grand total', 'importe total'];

    for (var line in lines) {
      for (var keyword in keywords) {
        if (line.contains(keyword)) {
          final match = RegExp(r'([0-9]+[.,][0-9]{2})').firstMatch(line);
          if (match != null) {
            return double.tryParse(match.group(1)!.replaceAll(',', '.'));
          }
        }
      }
    }

    // fallback: try bottom 5 lines
    for (var line in lines.reversed.take(5)) {
      final match = RegExp(r'([0-9]+[.,][0-9]{2})').firstMatch(line);
      if (match != null) {
        return double.tryParse(match.group(1)!.replaceAll(',', '.'));
      }
    }

    return null;
  }

  void _submitReceipt() {
    final cleanedText = _textController.text.trim();
    if (cleanedText.isEmpty) return;

    final total = extractTotalFromText(cleanedText);
    if (total == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't detect a total")),
      );
      return;
    }

    print("Parsed total: €$total");
    print("Raw text:\n$cleanedText");

    // TODO: Send this info to backend:
    // {
    //   "text": cleanedText,
    //   "total": total,
    //   "date": DateTime.now(),
    //   "payer": user.email or uid,
    //   "status": "paid"
    // }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Receipt submitted (mocked)")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Scan Receipt")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (_image != null)
              Image.file(_image!, height: 200),
            if (_scanning)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ),
            if (!_scanning && _image != null) ...[
              const SizedBox(height: 12),
              const Text("Extracted Text (edit if needed):"),
              TextField(
                controller: _textController,
                maxLines: 10,
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              if (_parsedTotal != null)
                Text("Detected Total: €${_parsedTotal!.toStringAsFixed(2)}"),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: _submitReceipt,
                icon: const Icon(Icons.send),
                label: const Text("Submit"),
              ),
            ],
            if (_image == null && !_scanning)
              Column(
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.photo_camera),
                    label: const Text("Take Photo"),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text("Pick from Gallery"),
                  ),
                ],
              )
          ],
        ),
      ),
    );
  }
}
