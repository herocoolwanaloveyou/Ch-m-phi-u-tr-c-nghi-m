import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;
import 'constants.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chấm Điểm Tự Động',
      theme: ThemeData(
        primaryColor: primaryColor,
        scaffoldBackgroundColor: backgroundColor,
        textTheme: const TextTheme(
          headlineSmall: titleStyle,
          bodyMedium: subtitleStyle,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(style: elevatedButtonStyle),
        cardTheme: CardTheme(
          color: cardColor,
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      SnackBar(
        content: Text('📸 Đã lưu ảnh: $imageName'),
        backgroundColor: secondaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [backgroundColor, Color(0xFFE5E7EB)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.assignment_turned_in_outlined,
                    size: 120, color: primaryColor),
                const SizedBox(height: 20),
                const Text(
                  'Chấm Điểm Tự Động',
                  style: titleStyle,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Chụp hoặc chọn ảnh phiếu trả lời để chấm điểm!',
                  style: subtitleStyle,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                _buildAnimatedButton(
                  context,
                  icon: Icons.camera_alt,
                  label: 'Chụp Ảnh Bài Thi',
                  onPressed: () => _captureAndSaveImage(context),
                ),
                const SizedBox(height: 20),
                _buildAnimatedButton(
                  context,
                  icon: Icons.photo_library,
                  label: 'Kho Ảnh & Chấm Điểm',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ImageGalleryPage()),
                  ),
                ),
                const SizedBox(height: 20),
                _buildAnimatedButton(
                  context,
                  icon: Icons.menu_book,
                  label: 'Quản Lý Đáp Án',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AnswerManagerPage()),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedButton(
      BuildContext context, {
        required IconData icon,
        required String label,
        required VoidCallback onPressed,
      }) {
    return AnimatedContainer(
      duration: animationDuration,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 24),
        label: Text(label, style: buttonTextStyle),
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 60),
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
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  Future<void> _loadImages() async {
    setState(() => isLoading = true);
    final dir = await getApplicationDocumentsDirectory();
    final files = Directory(dir.path).listSync();
    final filtered = files
        .whereType<File>()
        .where((f) => f.path.endsWith('.jpg') || f.path.endsWith('.png'))
        .toList();
    setState(() {
      images = filtered;
      isLoading = false;
    });
  }

  Future<void> _pickImageFromGallery() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final dir = await getApplicationDocumentsDirectory();
    final fileName = path.basename(picked.path);
    await File(picked.path).copy('${dir.path}/$fileName');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('🖼️ Đã thêm ảnh từ thiết bị'),
        backgroundColor: secondaryColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
    await _loadImages();
  }

  Future<void> _sendImageForGrading(File image) async {
    setState(() => isLoading = true);
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('http://10.0.179.178:5000/api/grade'),
      );
      request.files.add(await http.MultipartFile.fromPath('image', image.path));
      final response = await request.send();

      if (response.statusCode == 200) {
        final respStr = await response.stream.bytesToString();
        final result = jsonDecode(respStr);

        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Kết Quả Chấm Điểm', style: titleStyle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('📄 Mã đề: ${result["exam_code"]}'),
                Text('🏆 Điểm: ${result["score"]}/${result["total"]}'),
                const SizedBox(height: 10),
                Text('Đáp án:', style: subtitleStyle),
                Text(result["student_answers"].toString()),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK', style: TextStyle(color: primaryColor)),
              ),
            ],
          ),
        );
      } else {
        throw Exception('Lỗi server: ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Gửi ảnh thất bại: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _confirmDelete(File image) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Xóa Ảnh', style: titleStyle),
        content: const Text('Bạn có chắc chắn muốn xóa ảnh này không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await image.delete();
      await _loadImages();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('🗑️ Ảnh đã được xóa'),
          backgroundColor: secondaryColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _previewImage(File image) async {
    await showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(image, fit: BoxFit.contain),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _sendImageForGrading(image);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
                  child: const Text('Chấm Điểm', style: buttonTextStyle),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                  child: const Text('Đóng', style: buttonTextStyle),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kho Ảnh & Chấm Điểm'),
        backgroundColor: primaryColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_photo_alternate),
            onPressed: _pickImageFromGallery,
            tooltip: 'Thêm ảnh từ thư viện',
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : images.isEmpty
          ? const Center(
        child: Text(
          'Chưa có ảnh nào!\nHãy thêm ảnh từ thư viện hoặc chụp mới.',
          textAlign: TextAlign.center,
          style: subtitleStyle,
        ),
      )
          : GridView.builder(
        padding: const EdgeInsets.all(10),
        itemCount: images.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemBuilder: (_, index) {
          final image = images[index];
          return AnimatedContainer(
            duration: animationDuration,
            child: Stack(
              children: [
                GestureDetector(
                  onTap: () => _previewImage(image),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      image,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () => _confirmDelete(image),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.8),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.delete,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
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
          Map<int, String>.fromEntries((value as Map<String, dynamic>).entries
              .map((e) => MapEntry(int.parse(e.key), e.value as String))),
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

  Future<void> _addExamCode() async {
    final codeStr = await _showInputDialog('Nhập Mã Đề');
    final code = int.tryParse(codeStr ?? '');
    if (code == null || answerKeys.containsKey(code)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Mã đề không hợp lệ hoặc đã tồn tại!'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      answerKeys[code] = {};
    });
    await _saveAnswers();
  }

  Future<void> _editAnswers(int code) async {
    final answers = Map<int, String>.from(answerKeys[code]!);
    final totalStr = await _showInputDialog('Số Câu Hỏi', answers.length.toString());
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

  Future<void> _deleteExamCode(int code) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Xóa Mã Đề', style: titleStyle),
        content: Text('Bạn có chắc chắn muốn xóa mã đề $code không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        answerKeys.remove(code);
      });
      await _saveAnswers();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('🗑️ Đã xóa mã đề'),
          backgroundColor: secondaryColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<String?> _showInputDialog(String title, [String? initial]) async {
    return showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController(text: initial);
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(title, style: titleStyle),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('OK', style: TextStyle(color: primaryColor)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản Lý Đáp Án'),
        backgroundColor: primaryColor,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addExamCode,
        backgroundColor: primaryColor,
        child: const Icon(Icons.add),
      ),
      body: answerKeys.isEmpty
          ? const Center(
        child: Text(
          'Chưa có mã đề nào!\nHãy thêm mã đề mới.',
          textAlign: TextAlign.center,
          style: subtitleStyle,
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: answerKeys.length,
        itemBuilder: (_, index) {
          final code = answerKeys.keys.elementAt(index);
          return AnimatedContainer(
            duration: animationDuration,
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: primaryColor,
                  child: Text(
                    code.toString(),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text('Mã Đề $code', style: titleStyle.copyWith(fontSize: 18)),
                subtitle: Text('${answerKeys[code]!.length} câu hỏi', style: subtitleStyle),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: primaryColor),
                      onPressed: () => _editAnswers(code),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                      onPressed: () => _deleteExamCode(code),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}