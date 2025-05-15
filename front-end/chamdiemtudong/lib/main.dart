import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chấm điểm tự động',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        scaffoldBackgroundColor: const Color(0xFFF9F9F9),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(fontSize: 18.0),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 60),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            backgroundColor: Colors.grey[300],
            foregroundColor: Colors.black87,
          ),
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Future<void> _captureAndSaveImage(BuildContext context) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.camera);
    if (image == null) return;

    final dir = await getApplicationDocumentsDirectory();
    final imageName = path.basename(image.path);
    final savedImage = await File(image.path).copy('${dir.path}/$imageName');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('📸 Đã lưu ảnh: ${savedImage.path}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Chấm điểm tự động',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.assignment_turned_in, size: 100, color: Colors.grey),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: () => _captureAndSaveImage(context),
              icon: const Icon(Icons.camera_alt),
              label: const Text('Chụp ảnh bài thi'),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ImageGalleryPage()),
                );
              },
              icon: const Icon(Icons.photo_library),
              label: const Text('Kho ảnh & chấm điểm'),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AnswerManagerPage()),
                );
              },
              icon: const Icon(Icons.menu_book),
              label: const Text('Quản lý đáp án'),
            ),
          ],
        ),
      ),
    );
  }
}

class ImageGalleryPage extends StatefulWidget {
  const ImageGalleryPage({super.key});

  @override
  State<ImageGalleryPage> createState() => _ImageGalleryPageState();
}

class _ImageGalleryPageState extends State<ImageGalleryPage> {
  List<File> images = [];

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  Future<void> _loadImages() async {
    final dir = await getApplicationDocumentsDirectory();
    final files = Directory(dir.path).listSync();
    final filtered = files.whereType<File>().where((f) => f.path.endsWith('.jpg') || f.path.endsWith('.png')).toList();
    setState(() {
      images = filtered;
    });
  }

  Future<void> _pickImageFromGallery() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final dir = await getApplicationDocumentsDirectory();
    final fileName = path.basename(picked.path);
    final savedImage = await File(picked.path).copy('${dir.path}/$fileName');

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('🖼️ Đã thêm ảnh từ thiết bị')),
    );
    _loadImages();
  }

  void _sendImageForGrading(File image) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đang gửi ảnh để chấm điểm...')),
    );

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('http://192.168.1.61:5000/api/grade'),
      );
      request.files.add(await http.MultipartFile.fromPath('image', image.path));
      final response = await request.send();

      if (response.statusCode == 200) {
        final respStr = await response.stream.bytesToString();
        final result = jsonDecode(respStr);

        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Kết quả chấm điểm'),
            content: Text(
              '📄 Mã đề: ${result["exam_code"]}\n'
                  '🏆 Điểm: ${result["score"]}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        throw Exception('Lỗi server trả về');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Gửi ảnh thất bại: $e')),
      );
    }
  }

  void _confirmDelete(File image) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xóa ảnh'),
        content: const Text('Bạn có chắc chắn muốn xóa ảnh này không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await image.delete();
      _loadImages();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🗑️ Ảnh đã được xóa')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kho ảnh & chấm điểm'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_photo_alternate),
            onPressed: _pickImageFromGallery,
            tooltip: 'Thêm ảnh từ thư viện',
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(10),
        child: GridView.builder(
          itemCount: images.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemBuilder: (_, index) {
            final image = images[index];
            return Stack(
              children: [
                GestureDetector(
                  onTap: () => _sendImageForGrading(image),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(image, fit: BoxFit.cover, width: double.infinity, height: double.infinity),
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.white, size: 20),
                      onPressed: () => _confirmDelete(image),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class AnswerManagerPage extends StatefulWidget {
  const AnswerManagerPage({super.key});

  @override
  State<AnswerManagerPage> createState() => _AnswerManagerPageState();
}

class _AnswerManagerPageState extends State<AnswerManagerPage> {
  Map<int, Map<int, String>> answerKeys = {};

  @override
  void initState() {
    super.initState();
    _loadAnswers();
  }

  Future<void> _loadAnswers() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/answers.json');
    if (await file.exists()) {
      final content = await file.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;
      setState(() {
        answerKeys = data.map((key, value) => MapEntry(
          int.parse(key),
          Map<int, String>.fromEntries((value as Map<String, dynamic>).entries.map(
                (e) => MapEntry(int.parse(e.key), e.value as String),
          )),
        ));
      });
    }
  }

  Future<void> _saveAnswers() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/answers.json');
    final jsonContent = jsonEncode(answerKeys.map((key, value) => MapEntry(
      key.toString(),
      value.map((q, a) => MapEntry(q.toString(), a)),
    )));
    await file.writeAsString(jsonContent);
  }

  void _addExamCode() async {
    final codeStr = await _showInputDialog('Nhập mã đề');
    if (codeStr == null) return;
    final code = int.tryParse(codeStr);
    if (code == null || answerKeys.containsKey(code)) return;

    setState(() {
      answerKeys[code] = {};
    });
    await _saveAnswers();
  }

  void _editAnswers(int code) async {
    final answers = Map<int, String>.from(answerKeys[code]!);
    final totalStr = await _showInputDialog('Số câu hỏi', answers.length.toString());
    final total = int.tryParse(totalStr ?? '') ?? answers.length;

    for (int i = 1; i <= total; i++) {
      final existing = answers[i];
      final newAns = await _showInputDialog('Câu $i:', existing);
      if (newAns != null && newAns.toUpperCase().contains(RegExp(r'[ABCD]'))) {
        answers[i] = newAns.toUpperCase();
      }
    }

    setState(() {
      answerKeys[code] = answers;
    });
    await _saveAnswers();
  }

  void _deleteExamCode(int code) async {
    setState(() {
      answerKeys.remove(code);
    });
    await _saveAnswers();
  }

  Future<String?> _showInputDialog(String title, [String? initial]) async {
    return showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController(text: initial);
        return AlertDialog(
          title: Text(title),
          content: TextField(controller: controller),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quản lý đáp án')),
      floatingActionButton: FloatingActionButton(
        onPressed: _addExamCode,
        backgroundColor: Colors.grey[300],
        foregroundColor: Colors.black87,
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: answerKeys.keys.map((code) {
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              title: Text('Mã đề $code'),
              subtitle: Text('${answerKeys[code]!.length} câu hỏi'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.grey),
                    onPressed: () => _editAnswers(code),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.grey),
                    onPressed: () => _deleteExamCode(code),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
