import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'scan_page.dart';
import 'package:intl/intl.dart';

class OrderDetailsPage extends StatefulWidget {
  final Map<String, dynamic> order;

  const OrderDetailsPage({super.key, required this.order});

  @override
  _OrderDetailsPageState createState() => _OrderDetailsPageState();
}

class _OrderDetailsPageState extends State<OrderDetailsPage> {
  List<dynamic> details = [];
  List<dynamic> filteredDetails = [];
  bool isOrderCompleted = false;
  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchDetails();
    searchController.addListener(_filterDetails);
  }

  @override
  void dispose() {
    searchController.removeListener(_filterDetails);
    searchController.dispose();
    super.dispose();
  }

  Future<void> fetchDetails() async {
    final prefs = await SharedPreferences.getInstance();
    final String? accessToken = prefs.getString('accessToken');

    if (accessToken == null) {
      _showError('Токен не найден. Пожалуйста, войдите снова.');
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('http://127.0.0.1:8000/api/orders/${widget.order['order_id']}/details/'),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        final positions = json.decode(utf8.decode(response.bodyBytes))['positions'];
        setState(() {
          details = positions.where((detail) => !detail['is_completed']).toList();
          filteredDetails = details;
          isOrderCompleted = details.isEmpty;
        });
      } else {
        _showError('Не удалось загрузить детали заказа');
      }
    } catch (e) {
      _showError('Ошибка сети: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _filterDetails() {
    final query = searchController.text.toLowerCase();
    setState(() {
      filteredDetails = details.where((detail) {
        final color = detail['color'].toLowerCase();
        final size = detail['size'].toLowerCase();
        return color.contains(query) || size.contains(query);
      }).toList();
    });
  }

  String formatNumber(int number) {
    final formatter = NumberFormat('#,###', 'ru_RU');
    return formatter.format(number);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Детали заказа № ${widget.order['order_id']}',
          style: TextStyle(color: Colors.white),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.orange, Colors.red],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: fetchDetails,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                labelText: 'Поиск по размеру или цвету',
                labelStyle: TextStyle(color: Colors.deepPurple),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: Icon(Icons.search, color: Colors.deepPurple),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.deepPurple),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              keyboardType: TextInputType.text,
            ),
          ),
          Expanded(
            child: filteredDetails.isEmpty
                ? Center(
              child: isOrderCompleted
                  ? Text(
                'Заказ отсканирован полностью',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              )
                  : searchController.text.isEmpty
                  ? CircularProgressIndicator()
                  : Text(
                'Нет данных по поисковому запросу',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            )
                : ListView.builder(
              itemCount: filteredDetails.length,
              itemBuilder: (context, index) {
                final detail = filteredDetails[index];
                double progress = detail['scanned'] / detail['count'];
                Color progressColor;
                if (progress == 0) {
                  progressColor = Colors.red;
                } else if (progress < 0.5) {
                  progressColor = Colors.yellow;
                } else if (progress < 1) {
                  progressColor = Colors.lightGreen;
                } else {
                  progressColor = Colors.green;
                }

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            width: MediaQuery.of(context).size.width * progress,
                            color: progressColor.withOpacity(0.3),
                          ),
                        ),
                      ),
                      ListTile(
                        title: Row(
                          children: <Widget>[
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Размер: ${detail['size']}',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  Text('Цвет: ${detail['color']}'),
                                ],
                              ),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          'Количество: ${formatNumber(detail['count'])}\nОтсканировано: ${formatNumber(detail['scanned'])}\nОсталось: ${formatNumber(detail['remaining'])}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              detail['is_completed'] ? Icons.check_circle : Icons.cancel,
                              color: detail['is_completed'] ? Colors.green : Colors.red,
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.qr_code_scanner, color: Colors.orangeAccent),
                          ],
                        ),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => ScanPage(
                                positionId: detail['id'],
                                orderId: widget.order['order_id'],
                                size: detail['size'] ?? 'Не указан',
                                totalUnits: detail['count'],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}