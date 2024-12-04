import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'order_details_page.dart';
import 'package:intl/intl.dart';

class NoAggregationPage extends StatefulWidget {
  const NoAggregationPage({Key? key}) : super(key: key);

  @override
  _MenuPageState createState() => _MenuPageState();
}

class _MenuPageState extends State<NoAggregationPage> {
  List<dynamic> orders = [];
  List<dynamic> filteredOrders = [];
  TextEditingController searchController = TextEditingController();
  String selectedFilter = 'Все';

  @override
  void initState() {
    super.initState();
    fetchOrders();
    searchController.addListener(_filterOrders);
  }

  @override
  void dispose() {
    searchController.removeListener(_filterOrders);
    searchController.dispose();
    super.dispose();
  }

  Future<void> fetchOrders() async {
    final prefs = await SharedPreferences.getInstance();
    final String? accessToken = prefs.getString('access_token');

    if (accessToken == null) {
      _showError('Токен не найден. Пожалуйста, войдите снова.');
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('http://127.0.0.1:8000/api/orders/'),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          orders = json.decode(utf8.decode(response.bodyBytes));
          _filterOrders();
        });
      } else {
        final responseData = json.decode(utf8.decode(response.bodyBytes));
        final String errorMessage = responseData['detail'] ?? 'Не удалось загрузить заказы';
        _showError(errorMessage);
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

  void _filterOrders() {
    final query = searchController.text.toLowerCase();
    setState(() {
      filteredOrders = orders.where((order) {
        final orderId = order['order_id'].toString().toLowerCase();
        final vendorModel = order['vendor_model'].toString().toLowerCase();
        final matchesQuery = orderId.contains(query) || vendorModel.contains(query);

        if (selectedFilter == 'Все') {
          return matchesQuery;
        } else if (selectedFilter == 'Отсканированные') {
          return matchesQuery && order['is_completed'] == true;
        } else if (selectedFilter == 'Неотсканированные') {
          return matchesQuery && order['is_completed'] == false;
        }

        return false;
      }).toList();

      if (selectedFilter != 'Все' && filteredOrders.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Нет заказов для выбранного фильтра')),
        );
      }
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
        title: const Text(
          'Список заказов',
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
            onPressed: () {
              fetchOrders();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    labelText: 'Поиск по номеру заказа или артикулу',
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
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedFilter,
                  onChanged: (String? newValue) {
                    setState(() {
                      selectedFilter = newValue!;
                      _filterOrders();
                    });
                  },
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.deepPurple),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  items: <String>['Все', 'Отсканированные', 'Неотсканированные']
                      .map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          Expanded(
            child: filteredOrders.isEmpty
                ? Center(child: Text('Нет заказов для отображения'))
                : ListView.builder(
              itemCount: filteredOrders.length,
              itemBuilder: (context, index) {
                final order = filteredOrders[index];
                return Card(
                  color: Colors.grey[200],
                  elevation: 4,
                  margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListTile(
                    leading: Icon(Icons.shopping_cart, color: Colors.orangeAccent),
                    title: Text(
                      'Заказ № ${order['order_id']}',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Спецификация: ${order['specification']}\nАртикул: ${order['vendor_model']}\nКоличество: ${formatNumber(order['quantity'])}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          order['is_completed'] ? Icons.check_circle : Icons.cancel,
                          color: order['is_completed'] ? Colors.green : Colors.red,
                        ),
                        Icon(Icons.arrow_forward_ios, color: Colors.deepPurple),
                      ],
                    ),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => OrderDetailsPage(order: order),
                        ),
                      );
                    },
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