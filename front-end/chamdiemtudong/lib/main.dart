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
                  label: 'Kho Ảnh',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ImageGalleryPage()),
                  ),
                ),
                const SizedBox(height: 20),
                _buildAnimatedButton(
                  context,
                  icon: Icons.calculate,
                  label: 'Chấm Điểm Ngay',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const GradeScreen()),
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
  final bool isSelectingForGrading; // Thêm biến để xác định chế độ chọn ảnh

  const ImageGalleryPage({super.key, this.isSelectingForGrading = false});

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
      const SnackBar(
        content: Text('🖼️ Đã thêm ảnh từ thiết bị'),
        backgroundColor: secondaryColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
    await _loadImages();
  }

  Future<void> _captureAndSaveImage() async {
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
    await _loadImages();
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
        const SnackBar(
          content: Text('🗑️ Ảnh đã được xóa'),
          backgroundColor: secondaryColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _previewImage(File image) async {
    // Nếu đang ở chế độ chọn ảnh để chấm điểm, chỉ cần trả về ảnh đã chọn
    if (widget.isSelectingForGrading) {
      Navigator.pop(context, image);
      return;
    }

    // Nếu không, hiển thị dialog xem trước như trước
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
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GradeScreen(image: image),
                      ),
                    );
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
        title: Text(widget.isSelectingForGrading ? 'Chọn Ảnh Để Chấm Điểm' : 'Kho Ảnh'),
        backgroundColor: primaryColor,
        actions: widget.isSelectingForGrading
            ? [] // Ẩn các nút thêm ảnh nếu đang ở chế độ chọn
            : [
          IconButton(
            icon: const Icon(Icons.add_photo_alternate),
            onPressed: _pickImageFromGallery,
            tooltip: 'Thêm ảnh từ thư viện',
          ),
          IconButton(
            icon: const Icon(Icons.camera_alt),
            onPressed: _captureAndSaveImage,
            tooltip: 'Chụp ảnh mới',
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
                if (!widget.isSelectingForGrading) // Ẩn nút xóa nếu ở chế độ chọn
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
    try {
      final response = await http.get(
        Uri.parse('http://172.20.10.13:5000/api/get_answers'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        setState(() {
          answerKeys = data['answer_keys'].map<int, Map<int, String>>((key, value) => MapEntry(
            int.parse(key),
            Map<int, String>.fromEntries((value as Map<String, dynamic>).entries
                .map((e) => MapEntry(int.parse(e.key), e.value as String))),
          ));
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi tải danh sách mã đề: ${response.statusCode}'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi kết nối: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _sendToServer(String action, int code, Map<int, String>? answers) async {
    try {
      final response = await http.post(
        Uri.parse('http://172.20.10.13:5000/api/manage_answers'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': action,
          'code': code,
          'answers': answers?.map((q, a) => MapEntry(q.toString(), a)),
        }),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: secondaryColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
        await _loadAnswers();
      } else {
        final result = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: ${result['error']}'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi kết nối: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _addExamCode() async {
    final codeStr = await _showInputDialog('Nhập Mã Đề');
    final code = int.tryParse(codeStr ?? '');
    if (code == null || answerKeys.containsKey(code)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mã đề không hợp lệ hoặc đã tồn tại!'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    await _sendToServer('add', code, {});
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

    await _sendToServer('edit', code, answers);
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
      await _sendToServer('delete', code, null);
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

class GradeScreen extends StatefulWidget {
  final File? image;

  const GradeScreen({super.key, this.image});

  @override
  _GradeScreenState createState() => _GradeScreenState();
}

class _GradeScreenState extends State<GradeScreen> {
  File? _image;
  String _message = '';
  Map<String, dynamic>? _result;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.image != null) {
      setState(() {
        _image = widget.image;
      });
    }
  }

  Future<void> _pickImageFromStorage() async {
    // Điều hướng đến ImageGalleryPage ở chế độ chọn ảnh
    final selectedImage = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ImageGalleryPage(isSelectingForGrading: true),
      ),
    );

    if (selectedImage != null) {
      setState(() {
        _image = selectedImage as File;
        _message = '';
        _result = null;
      });
    }
  }

  Future<void> _gradeImage() async {
    if (_image == null) {
      setState(() {
        _message = 'Vui lòng chọn ảnh!';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _message = 'Đang chấm điểm...';
    });

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://172.20.10.13:5000/api/grade'),
      );
      request.files.add(await http.MultipartFile.fromPath('image', _image!.path));
      var response = await request.send();
      var responseData = await response.stream.bytesToString();

      print('Response from server in GradeScreen: $responseData');

      if (response.statusCode == 200) {
        final result = jsonDecode(responseData);
        if (result['status'] == 'success' &&
            result.containsKey('exam_code') &&
            result.containsKey('score') &&
            result.containsKey('total') &&
            result.containsKey('student_answers') &&
            result.containsKey('correct_answers')) {
          setState(() {
            _result = result;
            _message = 'Chấm điểm thành công!';
          });
        } else {
          setState(() {
            _result = null;
            _message = 'Lỗi: ${result['error'] ?? 'Dữ liệu không hợp lệ'}';
          });
        }
      } else {
        setState(() {
          _result = null;
          _message = 'Lỗi server: ${response.statusCode} - ${jsonDecode(responseData)['error'] ?? 'Không xác định'}';
        });
      }
    } catch (e) {
      setState(() {
        _result = null;
        _message = 'Lỗi kết nối hoặc xử lý: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chấm Điểm Ngay', style: titleStyle),
        backgroundColor: primaryColor,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [backgroundColor, Color(0xFFE5E7EB)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ElevatedButton.icon(
                  onPressed: _pickImageFromStorage,
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Chọn ảnh từ kho', style: buttonTextStyle),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    minimumSize: const Size(double.infinity, 60),
                  ),
                ),
                const SizedBox(height: 10),
                if (_image != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(_image!, height: 200, fit: BoxFit.cover),
                  ),
                  const SizedBox(height: 10),
                ],
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _gradeImage,
                  icon: _isLoading
                      ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                      : const Icon(Icons.calculate),
                  label: Text(
                    _isLoading ? 'Đang xử lý...' : 'Chấm Điểm',
                    style: buttonTextStyle,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    minimumSize: const Size(double.infinity, 60),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _message,
                  style: TextStyle(
                    color: _message.startsWith('Lỗi') || _message.startsWith('Vui lòng')
                        ? Colors.red
                        : secondaryColor,
                    fontSize: 16,
                  ),
                ),
                if (_result != null) ...[
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.description, color: primaryColor, size: 24),
                              const SizedBox(width: 8),
                              Text(
                                'Mã đề: ${_result!['exam_code'] ?? 'Không xác định'}',
                                style: titleStyle,
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Icon(Icons.emoji_events, color: primaryColor, size: 24),
                              const SizedBox(width: 8),
                              Text(
                                'Điểm: ${_result!['score'] ?? 0}/${_result!['total'] ?? 0}',
                                style: titleStyle.copyWith(fontSize: 20),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Đáp án & Kết quả:', style: titleStyle),
                          const SizedBox(height: 10),
                          ...(_result!['student_answers'] as Map? ?? {}).entries.map((entry) {
                            final questionNumber = entry.key;
                            final studentAnswer = entry.value;
                            final correctAnswer = (_result!['correct_answers'] as Map? ?? {})[questionNumber];
                            final isCorrect = studentAnswer == correctAnswer;

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: Row(
                                children: [
                                  Text(
                                    'Câu $questionNumber: ',
                                    style: subtitleStyle,
                                  ),
                                  Text(
                                    studentAnswer,
                                    style: subtitleStyle.copyWith(
                                      color: isCorrect ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                    ),
                                  ),
                                  if (!isCorrect) ...[
                                    const SizedBox(width: 8),
                                    const Text(
                                      '→',
                                      style: TextStyle(fontSize: 16, color: Colors.black),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      correctAnswer,
                                      style: subtitleStyle.copyWith(
                                        color: const Color(0xFF3B82F6),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: const Text('Xem Chi Tiết', style: buttonTextStyle),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}