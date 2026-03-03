import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

class WingsService {
  final String baseUrl;
  final _storage = const FlutterSecureStorage();
  String? _token;

  WingsService({required this.baseUrl});

  // Load token from device on app start
  Future<void> initialize() async {
    _token = await _storage.read(key: "auth_token");
  }

  bool get isLoggedIn => _token != null;

  Future<bool> login(String username, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "username": username,
        "password": password,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _token = data['token'];

      // Save token securely on device
      await _storage.write(key: "auth_token", value: _token);
      return true;
    }

    return false;
  }

  Future<void> logout() async {
    _token = null;
    await _storage.delete(key: "auth_token");
  }

  // 🚀 Efficient File Upload (Multipart)
  Future<bool> pushFile({
    required String projectId,
    required String version,
    required File file,
  }) async {
    if (_token == null) return false;

    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/push'),
    );

    request.headers['Authorization'] = 'Bearer $_token';

    request.fields['project_id'] = projectId;
    request.fields['version'] = version;

    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        file.path,
        filename: basename(file.path),
      ),
    );

    final response = await request.send();
    return response.statusCode == 200;
  }

  Future<File?> pullFile({
    required String projectId,
    required String version,
    required String savePath,
  }) async {
    if (_token == null) return null;

    final response = await http.get(
      Uri.parse('$baseUrl/pull?project_id=$projectId&version=$version'),
      headers: {
        'Authorization': 'Bearer $_token',
      },
    );

    if (response.statusCode == 200) {
      final file = File(savePath);
      await file.writeAsBytes(response.bodyBytes);
      return file;
    }

    return null;
  }
}




class UploadScreen extends StatefulWidget {
  @override
  _UploadScreenState createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  // 1. Initialize your service
  final WingsService _wingsService = WingsService(baseUrl: "https://your-api.com");
  
  // 2. Variables to hold user input
  File? _selectedFile;
  final _projectIdController = TextEditingController();
  final _versionController = TextEditingController();

  @override
  void dispose() {
    _projectIdController.dispose();
    _versionController.dispose();
    super.dispose();
  }

  // Function to let user pick a file
  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();

    if (result != null) {
      setState(() {
        _selectedFile = File(result.files.single.path!);
      });
    }
  }

Future<void> _handleUpload() async {
    if (_selectedFile == null) return;

    bool success = await _wingsService.pushFile(
      projectId: _projectIdController.text,
      version: _versionController.text,
      file: _selectedFile!,
    );

    messengerKey.currentState?.showSnackBar(
      SnackBar(content: Text(success ? "Upload Successful!" : "Upload Failed")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Wings File Uploader")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Text Input for Project ID
            TextField(
              controller: _projectIdController,
              decoration: InputDecoration(labelText: "Project ID"),
            ),
            TextField(
              controller: _versionController,
              decoration: InputDecoration(labelText: "Version"),
            ),
            const SizedBox(height: 20),
            
            // The File Selection Button
            ElevatedButton.icon(
              onPressed: _pickFile,
              icon: Icon(Icons.attach_file),
              label: Text(_selectedFile == null ? "Select File" : "File Selected: ${_selectedFile!.path.split('/').last}"),
            ),

            const Spacer(),

            // The Upload Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedFile == null ? null : _handleUpload,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                child: Text("PUSH TO SERVER"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final GlobalKey<ScaffoldMessengerState> messengerKey =
    GlobalKey<ScaffoldMessengerState>();
    

void main() {
  runApp(
    MaterialApp(
      scaffoldMessengerKey: messengerKey,
      home: UploadScreen(),
    ),
  );
}