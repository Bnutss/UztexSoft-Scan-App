import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'box_details_page.dart';

class AggregationBoxesPage extends StatelessWidget {
  const AggregationBoxesPage({super.key});

  Future<String?> _getToken() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null || token.isEmpty) {
      throw Exception('Токен отсутствует. Необходимо войти в систему.');
    }
    return token;
  }

  void _showSnackBar(BuildContext context, String message, Color color, IconData icon) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16.0),
      ),
    );
  }

  Future<void> _scanAndNavigate(BuildContext context, String scanCode, TextEditingController controller, FocusNode focusNode) async {
    final String? token = await _getToken();
    if (token == null) {
      _showSnackBar(
        context,
        'Ошибка: токен отсутствует. Войдите в систему.',
        Colors.red,
        Icons.error,
      );
      controller.clear();
      focusNode.requestFocus();
      return;
    }

    final url = Uri.parse('http://127.0.0.1:8000/api/box-scan/');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'scan_code': scanCode}),
      );
      final decodedResponse = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200) {
        final data = decodedResponse;
        _showSnackBar(
          context,
          'Коробка успешно обработана!',
          Colors.green,
          Icons.check_circle,
        );
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BoxDetailsPage(
              boxOrder: data['order_id']?.toString() ?? 'Неизвестная коробка',
              boxId: data['id'] ?? 0,
            ),
          ),
        );
      } else {
        final error = decodedResponse['error'];
        _showSnackBar(
          context,
          error,
          Colors.red,
          Icons.error,
        );
      }
    } catch (e) {
      _showSnackBar(
        context,
        'Ошибка соединения с сервером.',
        Colors.red,
        Icons.error,
      );
    }

    // Очистить поле и вернуть фокус
    controller.clear();
    focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final TextEditingController _controller = TextEditingController();
    final FocusNode _focusNode = FocusNode();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Сканирование коробки',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFFDD7B35),
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFDD7B35), Color(0xFFAE2E2E)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              TextField(
                controller: _controller,
                focusNode: _focusNode,
                decoration: InputDecoration(
                  hintText: 'Отсканируйте код коробки...',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                onSubmitted: (value) {
                  _scanAndNavigate(context, value, _controller, _focusNode);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}