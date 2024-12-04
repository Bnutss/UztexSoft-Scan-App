import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:intl/intl.dart';

class ScanPage extends StatefulWidget {
  final int positionId;
  final String orderId;
  final String size;
  final int totalUnits;

  const ScanPage({
    Key? key,
    required this.positionId,
    required this.orderId,
    required this.size,
    required this.totalUnits,
  }) : super(key: key);

  @override
  _ScanPageState createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  MobileScannerController cameraController = MobileScannerController();
  int scannedUnits = 0;
  bool scanningCompleted = false;

  @override
  void initState() {
    super.initState();
    loadInitialScannedUnits();
  }

  void loadInitialScannedUnits() async {
    final prefs = await SharedPreferences.getInstance();
    final String? accessToken = prefs.getString('accessToken');

    if (accessToken == null) {
      _showCustomSnackBar('Токен не найден. Пожалуйста, войдите снова.', isSuccess: false);
      return;
    }

    final response = await http.get(
      Uri.parse('http://127.0.0.1:8000/api/get_scanned_units/${widget.positionId}/'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        scannedUnits = data['scanned_units'];
        if (scannedUnits >= widget.totalUnits) {
          scanningCompleted = true;
        }
      });
    } else {
      _showCustomSnackBar('Не удалось загрузить данные', isSuccess: false);
    }
  }

  void validateCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    final String? accessToken = prefs.getString('accessToken');

    if (accessToken == null) {
      _showCustomSnackBar('Токен не найден. Пожалуйста, войдите снова.', isSuccess: false);
      return;
    }

    final response = await http.post(
      Uri.parse('http://127.0.0.1:8000/api/validate_code/${widget.positionId}/'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({'datamatrix': code}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        scannedUnits = data['scanned_units'];
        if (scannedUnits >= widget.totalUnits) {
          scanningCompleted = true;
          _showCustomSnackBar('Все коды успешно отсканированы!', isSuccess: true);
        }
      });
      _showCustomSnackBar(data['message'], isSuccess: true);
    } else {
      final data = jsonDecode(response.body);
      _showCustomSnackBar(data['message'] ?? 'Ошибка при сканировании', isSuccess: false);
    }
  }

  void _showCustomSnackBar(String message, {required bool isSuccess}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isSuccess ? Icons.check_circle : Icons.error, color: Colors.white),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isSuccess ? Colors.green : Colors.red,
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
        ),
      ),
    );
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
          'Сканирование',
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
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                MobileScanner(
                  controller: cameraController,
                  onDetect: (capture) {
                    if (!scanningCompleted) {
                      final List<Barcode> barcodes = capture.barcodes;
                      for (final barcode in barcodes) {
                        final String? code = barcode.rawValue;
                        if (code != null) {
                          validateCode(code);
                        }
                      }
                    }
                  },
                ),
                Center(
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.green, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildInfoRow(Icons.shopping_cart, 'Заказ', widget.orderId),
                    _buildInfoRow(Icons.straighten, 'Размер', widget.size),
                    _buildProgressIndicator(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.orangeAccent),
            SizedBox(width: 8),
            Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        Text(value, style: TextStyle(fontSize: 16)),
      ],
    );
  }

  Widget _buildProgressIndicator() {
    double progress = scannedUnits / widget.totalUnits;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Прогресс', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text('${formatNumber(scannedUnits)} / ${formatNumber(widget.totalUnits)}', style: TextStyle(fontSize: 16)),
          ],
        ),
        SizedBox(height: 8),
        Container(
          height: 20,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: Colors.grey[300],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
            ),
          ),
        ),
      ],
    );
  }
}
//////////