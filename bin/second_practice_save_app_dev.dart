import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:io';
import 'package:crypto/crypto.dart';

void main() async {
  // Предложим пользователю выбрать источник хэш-значений
  List<String> md5Hashes = [];
  List<String> sha256Hashes = [];

  print('Выберите источник хэш-значений: 1 - Файл, 2 - Ввод с консоли, 3 - использовать введённые в программу');
  String? inputChoice = stdin.readLineSync();

  if (inputChoice == '1') {
    print('Введите путь к файлу с хэш-значениями:');
    String? filePath = stdin.readLineSync();
    if (filePath != null && filePath.isNotEmpty) {
      await readHashesFromFile(filePath, md5Hashes, sha256Hashes);
    }
  } else if (inputChoice == '2') {
    readHashesFromConsole(md5Hashes, sha256Hashes);}

    else if(inputChoice == '3'){
    md5Hashes = ['7a68f09bd992671bb3b19a5e70b7827e'];
    sha256Hashes = [
      '1115dd800feaacefdf481f1f9070374a2a81e27880f187396db67958b207cbad',
      '3a7bd3e2360a3d29eea436fcfb7e44c735d117c42d1c1835420b6b9942dd4f1b',
      '74e1bb62f8dabb8125a58852b63bdf6eaef667cb56ac7f7cdba6d7305c50a22f'
    ];
  } else {
    print('Неверный выбор источника хэш-значений.');
    return;
  }

  print('Выберите режим: 1 - Однопоточный, 2 - Многопоточный');
  String? modeChoice = stdin.readLineSync();
  if (modeChoice == '1') {
    await singleThreadedMode(md5Hashes, sha256Hashes);
  } else if (modeChoice == '2') {
    print('Введите количество потоков:');
    int threadCount = int.parse(stdin.readLineSync()!);
    await multiThreadedMode(md5Hashes, sha256Hashes, threadCount);
  } else {
    print('Неверный выбор. Завершение программы.');
  }
}

// Функция для чтения хэш-значений из файла
Future<void> readHashesFromFile(String filePath, List<String> md5Hashes, List<String> sha256Hashes) async {
  try {
    final file = File(filePath);
    List<String> lines = await file.readAsLines();

    for (String line in lines) {
      if (line.length == 32) {
        md5Hashes.add(line);
      } else if (line.length == 64) {
        sha256Hashes.add(line);
      }
    }
    print('Хэш-значения успешно загружены из файла.');
  } catch (e) {
    print('Ошибка при чтении файла: $e');
  }
}

// Функция для чтения хэш-значений с консоли
void readHashesFromConsole(List<String> md5Hashes, List<String> sha256Hashes) {
  print('Введите хэш-значения (MD5 или SHA-256), по одному на строку. Введите "end" для завершения ввода:');
  while (true) {
    String? input = stdin.readLineSync();
    if (input == null || input.toLowerCase() == 'end') {
      break;
    } else if (input.length == 32) {
      md5Hashes.add(input);
    } else if (input.length == 64) {
      sha256Hashes.add(input);
    } else {
      print('Неверное хэш-значение. Введите MD5 (32 символа) или SHA-256 (64 символа).');
    }
  }
}

// Однопоточный режим
Future<void> singleThreadedMode(List<String> md5Hashes, List<String> sha256Hashes) async {
  final stopwatch = Stopwatch()..start();
  bruteForce(md5Hashes, sha256Hashes);
  stopwatch.stop();
  print('Однопоточный режим завершен за: ${stopwatch.elapsed}');
}

// Многопоточный режим
Future<void> multiThreadedMode(List<String> md5Hashes, List<String> sha256Hashes, int threadCount) async {
  final stopwatch = Stopwatch()..start();
  List<Future<void>> isolates = [];

  // Делим поиск между потоками
  for (int i = 0; i < threadCount; i++) {
    isolates.add(runIsolate(md5Hashes, sha256Hashes, i, threadCount));
  }

  await Future.wait(isolates);
  stopwatch.stop();
  print('Многопоточный режим завершен за: ${stopwatch.elapsed}');
}

// Запуск изолята для многопоточного перебора
Future<void> runIsolate(List<String> md5Hashes, List<String> sha256Hashes, int isolateIndex, int totalIsolates) async {
  ReceivePort receivePort = ReceivePort();
  await Isolate.spawn(_isolateEntry, [receivePort.sendPort, md5Hashes, sha256Hashes, isolateIndex, totalIsolates]);
  await receivePort.first;
}

// Входная точка для изолята
void _isolateEntry(List<dynamic> args) {
  SendPort sendPort = args[0];
  List<String> md5Hashes = args[1];
  List<String> sha256Hashes = args[2];
  int isolateIndex = args[3];
  int totalIsolates = args[4];

  bruteForce(md5Hashes, sha256Hashes, isolateIndex, totalIsolates);
  sendPort.send(null);
}

// Функция перебора паролей
void bruteForce(List<String> md5Hashes, List<String> sha256Hashes, [int isolateIndex = 0, int totalIsolates = 1]) {
  const letters = 'abcdefghijklmnopqrstuvwxyz';
  int length = letters.length;

  for (int i = isolateIndex; i < length * length * length * length * length; i += totalIsolates) {
    String password = getPasswordFromIndex(i, letters);
    String md5Hash = md5.convert(utf8.encode(password)).toString();
    String sha256Hash = sha256.convert(utf8.encode(password)).toString();

    if (md5Hashes.contains(md5Hash)) {
      print('Найден пароль для MD5: $password -> $md5Hash');
    }
    if (sha256Hashes.contains(sha256Hash)) {
      print('Найден пароль для SHA-256: $password -> $sha256Hash');
    }
  }
}

// Функция для получения пароля по индексу
String getPasswordFromIndex(int index, String letters) {
  int length = letters.length;
  String password = '';
  for (int i = 0; i < 5; i++) {
    password = letters[index % length] + password;
    index ~/= length;
  }
  return password;
}
