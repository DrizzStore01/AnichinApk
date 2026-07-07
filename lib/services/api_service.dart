import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/home_model.dart';

class ApiService {
  static const String baseUrl = 'https://api.nexray.eu.cc/anime/anichin';

  Future<HomeData> getHome() async {
    final response = await http.get(Uri.parse('$baseUrl/home'));

    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonData = json.decode(response.body);

      if (jsonData['status'] == true) {
        return HomeData.fromJson(jsonData);
      } else {
        throw Exception('API mengembalikan status false');
      }
    } else {
      throw Exception('Gagal fetch data. Kode: ${response.statusCode}');
    }
  }
}
