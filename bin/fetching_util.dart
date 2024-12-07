import 'package:html/parser.dart';
import 'package:http/http.dart' as http;

final class NetworkUtil {
  final String cookies;

  NetworkUtil({required this.cookies});

  static final http.Client client = http.Client();
  


  /// Функция для загрузки index.php с использованием cookie
  Future<String?> fetchIndexPage(String url) async {
    try {
      final response = await client.get(
        Uri.parse(url),
        headers: {
          'Cookie': cookies,
        },
      );

      if (response.statusCode == 200) {
        return response.body;
      } else {
        print("Ошибка: статус ответа ${response.statusCode}");
      }
    } catch (e) {
      print("Ошибка при загрузке index.php: $e");
    }
    return null;
  }

  /// Функция для получения user_token
  Future<String?> fetchUserToken(String baseUrl) async {
    try {
      final response = await client.get(Uri.parse(baseUrl));
      if (response.statusCode == 200) {
        final document = parse(response.body);
        final tokenInput = document.querySelector('input[name="user_token"]');
        return tokenInput?.attributes['value'];
      }
    } catch (e) {
      print('Ошибка получения user_token: $e');
    }
    return null;
  }

  /// Функция для отправки запроса на сервер DVWA
  Future<bool> attemptLogin(String baseUrl, String username, String password,
      String userToken) async {
    final uri =
        Uri.parse('$baseUrl?username=$username&password=$password&Login=Login');

    try {
      final response = await client.get(
        uri,
        headers: {
          'Cookie': cookies,
        },
      );
      return response.body.contains('Welcome to the password protected area');
    } catch (e) {
      print('Ошибка при запросе: $e');
      return false;
    }
  }
}
