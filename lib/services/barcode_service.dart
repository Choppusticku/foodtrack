import 'dart:convert';
import 'package:http/http.dart' as http;

class BarcodeService {
  static Future<String?> fetchItemNameFromBarcode(String code) async {
    final response = await http.get(Uri.parse(
        "https://world.openfoodfacts.org/api/v0/product/$code.json"));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['product']?['product_name'];
    }
    return null;
  }
}
