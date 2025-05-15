import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OCR App',
      home: OCRScreen(),
    );
  }
}

class OCRScreen extends StatefulWidget {
  @override
  _OCRScreenState createState() => _OCRScreenState();
}

class _OCRScreenState extends State<OCRScreen> {
  File? _imageFile;
  String _ocrResult = "";

  Future<void> captureAndSend() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera);
    if (image == null) return;

    setState(() {
      _imageFile = File(image.path);
    });

    final uri = Uri.parse("http://<IP_MAY_TINH>:5000/ocr");
    final request = http.MultipartRequest('POST', uri)
      ..files.add(await http.MultipartFile.fromPath('image', image.path));

    final response = await request.send();
    final resBody = await response.stream.bytesToString();
    final data = json.decode(resBody);

    setState(() {
      _ocrResult = data['text'] ?? 'Không có kết quả.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("OCR Chụp Hình")),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: captureAndSend,
              child: Text("📸 Chụp ảnh & Nhận dạng"),
            ),
            SizedBox(height: 20),
            if (_imageFile != null) Image.file(_imageFile!, height: 200),
            SizedBox(height: 20),
            Text("📄 Kết quả OCR:", style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Expanded(child: SingleChildScrollView(child: Text(_ocrResult))),
          ],
        ),
      ),
    );
  }
}
