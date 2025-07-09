import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;


class ScanReceiptScreen extends StatefulWidget {
  const ScanReceiptScreen({super.key});

  @override
  State<ScanReceiptScreen> createState() => _ScanReceiptScreenState();
}

class _ScanReceiptScreenState extends State<ScanReceiptScreen> {
  File? _image;
  File? _compressedImage;
  String _extractedText = '';
  double? _parsedTotal;
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _manualTotalController = TextEditingController();
  bool _scanning = false;
  bool _showBanner = true;
  bool _showRawText = false;
  int _skipCandidateCount = 0;

  Future<void> _pickImage(ImageSource source) async {
    final picked = await ImagePicker().pickImage(source: source);
    if (picked == null) return;

    setState(() {
      _image = File(picked.path);
      _scanning = true;
      _extractedText = '';
      _parsedTotal = null;
      _skipCandidateCount = 0;
    });

    final inputImage = InputImage.fromFile(_image!);
    final textRecognizer = GoogleMlKit.vision.textRecognizer();
    final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
    await textRecognizer.close();

    final rawText = recognizedText.text;
    final total = extractTotalFromText(rawText);

    setState(() {
      _extractedText = rawText;
      _textController.text = rawText;
      _parsedTotal = total;
      _manualTotalController.text = total?.toStringAsFixed(2) ?? '';
      _scanning = false;
    });

    await _compressImage(_image!);
  }

  Future<void> _compressImage(File original) async {
    final rawBytes = await original.readAsBytes();
    final decoded = img.decodeImage(rawBytes);
    if (decoded == null) return;

    final dir = await getTemporaryDirectory();
    final target = File('${dir.path}/compressed.jpg');
    final compressed = img.encodeJpg(decoded, quality: 70);
    await target.writeAsBytes(compressed);

    setState(() {
      _compressedImage = target;
    });
  }

  double? extractTotalFromText(String rawText, {int skipTop = 0}) {
    final lines = rawText
        .split('\n')
        .map((line) => line.trim().toLowerCase())
        .where((line) => line.isNotEmpty)
        .toList();

    final priceRegex = RegExp(r'([0-9]+[.,] ?[0-9]{2,3})');
    final strongLabels = ['total', 'importe', 'suma', 'pagar', 'bruto'];
    final weakLabels = ['iva', 'cambio', 'tarjeta', 'efectivo', 'visa'];

    final Map<double, int> candidates = {};
    final List<double> allValues = [];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final matches = priceRegex.allMatches(line);

      for (final match in matches) {
        String raw = match.group(1)!.replaceAll(',', '.').replaceAll(' ', '');
        if (!RegExp(r'^\d+\.\d{2}$').hasMatch(raw)) continue;

        final value = double.tryParse(raw);
        if (value == null) continue;

        if (!candidates.containsKey(value)) allValues.add(value);

        int score = 0;
        final context = [
          if (i > 1) lines[i - 2],
          if (i > 0) lines[i - 1],
          line,
          if (i < lines.length - 1) lines[i + 1],
          if (i < lines.length - 2) lines[i + 2],
        ].join(' ');

        if (strongLabels.any((kw) => context.contains(kw))) score += 3;
        if (!weakLabels.any((kw) => context.contains(kw))) score += 2;
        if (line.contains('€')) score += 1;
        if (i > 2) score += 1;
        if (line == raw || line.trim() == '$raw €') score += 1;
        if (i >= lines.length - 6) score += 1;

        candidates[value] = (candidates[value] ?? 0) + score;
      }
    }

    if (candidates.isEmpty) return null;

    allValues.sort();
    final cutoff = allValues[(allValues.length / 4).floor()];
    final maxValue = allValues.isNotEmpty ? allValues.last : 0;

    candidates.updateAll((value, score) {
      int adjusted = score;
      if (value < cutoff) adjusted -= 10;
      if (value < maxValue * 0.5) adjusted -= 4;
      final decimalPart = (value * 100).toInt() % 100;
      if ([0, 99, 50].contains(decimalPart)) adjusted -= 1;
      return adjusted;
    });

    final sorted = candidates.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return skipTop < sorted.length ? sorted[skipTop].key : null;
  }

  void _submitReceipt() {
    final cleanedText = _textController.text.trim();
    final userTotal = double.tryParse(_manualTotalController.text.replaceAll(',', '.'));
    if (cleanedText.isEmpty || userTotal == null) return;

    print("Parsed total: €$userTotal");
    print("Raw text:\n$cleanedText");
    print("Image path (compressed): ${_compressedImage?.path}");

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Receipt submitted (mocked)")),
    );
  }

  void _tryNextCandidate() {
    setState(() {
      _skipCandidateCount++;
      _parsedTotal = extractTotalFromText(_textController.text, skipTop: _skipCandidateCount);
      _manualTotalController.text = _parsedTotal?.toStringAsFixed(2) ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Scan Receipt"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            setState(() {
              _image = null;
              _compressedImage = null;
              _parsedTotal = null;
              _extractedText = '';
              _textController.clear();
              _manualTotalController.clear();
              _showBanner = true;
              _skipCandidateCount = 0;
              _showRawText = false;
            });
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (_showBanner)
              MaterialBanner(
                backgroundColor: Colors.orange,
                content: const Text(
                  "⚠️ This feature is in beta. Please verify the total before submitting.",
                  style: TextStyle(color: Colors.black),
                ),
                actions: [
                  TextButton(
                    onPressed: () => setState(() => _showBanner = false),
                    child: const Text("OK", style: TextStyle(color: Colors.black)),
                  ),
                ],
              ),
            if (_image != null) Image.file(_image!, height: 200),
            if (_scanning)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ),
            if (!_scanning && _image != null) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_parsedTotal != null)
                    Expanded(
                      child: TextField(
                        controller: _manualTotalController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: "Detected Total (€)"),
                      ),
                    ),
                  TextButton(onPressed: _tryNextCandidate, child: const Text("Try Next")),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => setState(() => _showRawText = !_showRawText),
                icon: const Icon(Icons.text_snippet),
                label: Text(_showRawText ? "Hide Raw Text" : "Show Raw Text"),
              ),
              if (_showRawText)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: TextField(
                    controller: _textController,
                    maxLines: 10,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                  ),
                ),
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
