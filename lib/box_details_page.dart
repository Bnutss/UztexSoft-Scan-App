import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class BoxDetailsPage extends StatefulWidget {
  final String boxOrder;
  final int boxId;

  const BoxDetailsPage({
    required this.boxOrder,
    required this.boxId,
    super.key,
  });

  @override
  State<BoxDetailsPage> createState() => _BoxDetailsPageState();
}

class _BoxDetailsPageState extends State<BoxDetailsPage> {
  final TextEditingController _scanController = TextEditingController();
  final FocusNode _scanFocusNode = FocusNode();
  int _scannedCount = 0;
  int _limit = 0;
  List<Map<String, dynamic>> _scannedProducts = [];
  double _progress = 0.0;
  bool _isBoxClosed = false;
  bool _isBoxUsed = false;

  @override
  void initState() {
    super.initState();
    _fetchBoxDetails();
  }

  @override
  void dispose() {
    _scanController.dispose();
    _scanFocusNode.dispose();
    super.dispose();
  }

  Future<void> _closeBox() async {
    final String? token = await _getToken();
    if (token == null) {
      _showSnackbar('Ошибка: токен отсутствует. Войдите в систему.', Colors.red, Icons.error);
      return;
    }

    final url = Uri.parse('http://127.0.0.1:8000/api/close-box/${widget.boxId}/');
    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        _showSnackbar('Коробка успешно закрыта.', Colors.green, Icons.check);
        setState(() {
          _isBoxClosed = true;
        });
      } else {
        final error = jsonDecode(utf8.decode(response.bodyBytes))['error'];
        _showSnackbar('Ошибка: $error', Colors.red, Icons.error);
      }
    } catch (e) {
      _showSnackbar('Ошибка соединения: $e', Colors.red, Icons.error);
    }
  }

  Future<String?> _getToken() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null || token.isEmpty) {
      throw Exception('Токен отсутствует. Необходимо войти в систему.');
    }
    return token;
  }

  Future<void> _fetchBoxDetails() async {
    final String? token = await _getToken();
    if (token == null) {
      _showSnackbar('Ошибка: токен отсутствует. Войдите в систему.', Colors.red, Icons.error);
      return;
    }

    final url = Uri.parse('http://127.0.0.1:8000/api/box-details/${widget.boxId}/');
    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() {
          _scannedCount = data['scanned_count'] ?? 0;
          _limit = data['limit'] ?? 0;
          _scannedProducts = List<Map<String, dynamic>>.from(data['scanned_products']);
          _progress = (_scannedCount / _limit).clamp(0.0, 1.0);
          _isBoxUsed = data['is_used'] ?? false; // Обновляем статус is_used
        });
      } else {
        _showSnackbar('Ошибка загрузки данных коробки. Код: ${response.statusCode}', Colors.red, Icons.error);
      }
    } catch (e) {
      _showSnackbar('Ошибка соединения: $e', Colors.red, Icons.error);
    }
  }

  Future<void> _deleteProduct(int productId) async {
    final String? token = await _getToken();
    if (token == null) {
      _showSnackbar('Ошибка: токен отсутствует. Войдите в систему.', Colors.red, Icons.error);
      return;
    }

    final url = Uri.parse('http://127.0.0.1:8000/api/box-details/${widget.boxId}/$productId/');
    try {
      final response = await http.delete(
        url,
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          _scannedProducts.removeWhere((product) => product['id'] == productId);
          _scannedCount -= 1;
          _progress = (_scannedCount / _limit).clamp(0.0, 1.0);
        });
        _showSnackbar('Товар успешно удален из коробки.', Colors.green, Icons.check);
      } else {
        final error = jsonDecode(utf8.decode(response.bodyBytes))['error'];
        _showSnackbar('Ошибка: $error', Colors.red, Icons.error);
      }
    } catch (e) {
      _showSnackbar('Ошибка соединения: $e', Colors.red, Icons.error);
    }
  }

  Future<void> _scanProduct(String dmCode) async {
    final String? token = await _getToken();
    if (token == null) {
      _showSnackbar('Ошибка: токен отсутствует. Войдите в систему.', Colors.red, Icons.error);
      _clearAndRefocus();
      return;
    }

    final url = Uri.parse('http://127.0.0.1:8000/api/scan-product-to-box/');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'dm_code': dmCode, 'box_id': widget.boxId}),
      );

      if (response.statusCode == 200) {
        _fetchBoxDetails();
        _showSnackbar('Товар успешно привязан к коробке.', Colors.green, Icons.check);
      } else {
        final error = jsonDecode(utf8.decode(response.bodyBytes))['error'];
        _showSnackbar('Ошибка: $error', Colors.red, Icons.error);
      }
    } catch (e) {
      _showSnackbar('Ошибка соединения: $e', Colors.red, Icons.error);
    } finally {
      _clearAndRefocus();
    }
  }

  void _clearAndRefocus() {
    _scanController.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scanFocusNode.requestFocus();
    });
  }

  void _showSnackbar(String message, Color color, IconData icon) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16.0),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Отсканировано $_scannedCount / $_limit',
              style: const TextStyle(fontSize: 14, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFDD7B35),
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchBoxDetails,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!_isBoxClosed)
                TextField(
                  controller: _scanController,
                  focusNode: _scanFocusNode,
                  enabled: !_isBoxClosed && !_isBoxUsed, // Поле недоступно, если коробка закрыта или использована
                  decoration: InputDecoration(
                    hintText: 'Отсканируйте КМ код',
                    filled: true,
                    fillColor: Colors.grey[200],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  onSubmitted: (value) {
                    if (value.isNotEmpty) {
                      _scanProduct(value.trim());
                    } else {
                      _showSnackbar('Отсканируйте КМ код', Colors.red, Icons.error);
                      _clearAndRefocus();
                    }
                  },
                ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.builder(
                  itemCount: _scannedProducts.length,
                  itemBuilder: (context, index) {
                    final product = _scannedProducts[index];
                    return Dismissible(
                      key: Key(product['id'].toString()),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (direction) {
                        _deleteProduct(product['id']);
                      },
                      child: Card(
                        margin: const EdgeInsets.symmetric(vertical: 5.0),
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text('${index + 1}'),
                          ),
                          title: Text(
                            'Размер: ${product['order_position__size__size'] ?? 'Не указан'}',
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Цвет: ${product['order_position__color__color'] ?? 'Не указан'}',
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Код: ${product['datamatrix__dm_code'] ?? 'Не указан'}',
                                style: const TextStyle(
                                  fontSize: 8,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: Colors.grey[200],
                  color: Colors.green,
                ),
              ),
              ElevatedButton.icon(
                onPressed: (_isBoxClosed || _isBoxUsed) ? null : _closeBox, // Кнопка недоступна, если коробка закрыта или использована
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                icon: const Icon(Icons.lock, color: Colors.white),
                label: const Text(
                  'Закрыть коробку',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}