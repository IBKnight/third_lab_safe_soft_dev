## Запуск
- Скачайте Docker;
- склоньте репозиторий [DVWA](https://github.com/digininja/DVWA);
- откройте терминал и перейдите в папку `DVWA`;
- запустите комадну `docker compose up -d`;
- откройте в браузере `http://localhost:4280`;
- войдите в аккаунт с кредами админа;
- склоньте репозиторий с кодом bruteforce;
- подтяните все зависимости проекта с помощью `(в начале указать fvm, если он есть) dart pub get`;
- из DevTools скопируйте PHPSESSID;
- вставьте id сессии в файле `third_practice.dart` в переменную 
```dart
  String cookie = "security=low; PHPSESSID=051d9569cc477bae29f09a15fc1a6ad3";
```
- запустите программу с помощью `(в начале указть fvm, если он есть) dart run bin\third_practice.dart`

### Скриншоты
**Перебор пароля для user'а gordonb**
<div  style="display: flex; justify-content: center;">
    <img src="images\bruteforce_process.png" alt="Screenshot 1" style="width: 200px; margin-right: 10px;">
    <img src="images\success.png" alt="Screenshot 2" style="width: 400px; margin-right: 10px;">
</div>

### Ревью кода с указанием слабостей по метрике CWE 

Код для ревью:
```php
<?php

if( isset( $_GET[ 'Login' ] ) ) {
	// Get username
	$user = $_GET[ 'username' ];
	// Get password
	$pass = $_GET[ 'password' ];
	$pass = md5( $pass );
	// Check the database
	$query  = "SELECT * FROM `users` WHERE user = '$user' AND password = '$pass';";
	$result = mysqli_query($GLOBALS["___mysqli_ston"],  $query ) or die( '<pre>' . ((is_object($GLOBALS["___mysqli_ston"])) ? mysqli_error($GLOBALS["___mysqli_ston"]) : (($___mysqli_res = mysqli_connect_error()) ? $___mysqli_res : false)) . '</pre>' );
	if( $result && mysqli_num_rows( $result ) == 1 ) {
		// Get users details
		$row    = mysqli_fetch_assoc( $result );
		$avatar = $row["avatar"];
		// Login successful
		$html .= "<p>Welcome to the password protected area {$user}</p>";
		$html .= "<img src=\"{$avatar}\" />";
	}
	else {
		// Login failed
		$html .= "<pre><br />Username and/or password incorrect.</pre>";
	}
	((is_null($___mysqli_res = mysqli_close($GLOBALS["___mysqli_ston"]))) ? false : $___mysqli_res);
}
?>
```


#### 1. **SQL-инъекция (CWE-89)**

**Описание:** Строка `$query = "SELECT * FROM` users `WHERE user = '$user' AND password = '$pass';";` уязвима для SQL-инъекций, так как пользовательский ввод напрямую используется в SQL-запросе без фильтрации или параметризации.

**Пример эксплуатации:** Если `username` равен `' OR 1=1--` и `password` равен чему угодно, запрос становится:

```sql
SELECT * FROM `users` WHERE user = '' OR 1=1-- AND password = '...';
```

Это позволяет злоумышленнику получить доступ ко всем данным.

#### 2. **Хранение пароля в виде хэша MD5 (CWE-327)**

**Описание:** Использование `md5` для хэширования пароля ненадёжно, так как MD5 считается криптографически слабым. Современные атаки, такие как перебор с использованием GPU, делают его взлом простым.

#### 3. **Уязвимость к XSS-атакам (CWE-79)**

**Описание:** Переменные `$user` и `$avatar` выводятся на страницу без экранирования, что позволяет злоумышленнику внедрить вредоносный скрипт.

**Пример эксплуатации:** Если `username` содержит `<script>alert('XSS')</script>`, то это скрипт выполнится на странице.

#### 4. **Неправильное ограничение чрезмерных попыток аутентификации (CWE-307)**

**Описание:** Код не ограничивает количество попыток аутентификации (например, при вводе логина и пароля). В результате злоумышленник может использовать брутфорс для подбора пароля.


#### 5. **Разглашение внутренней информации (CWE-209)**

**Описание:** Сообщения об ошибках, такие как `die('<pre>' . mysqli_error($GLOBALS["___mysqli_ston"]) . '</pre>');`, выводят информацию об архитектуре базы данных и могут быть использованы злоумышленником.

### Исправленный код с учётом слабостей
```php
<?php

// Проверка, что запрос выполнен через POST и обязательные поля переданы
if ($_SERVER['REQUEST_METHOD'] === 'POST' && !empty($_POST['Login']) && !empty($_POST['username']) && !empty($_POST['password'])) {
    
    // Проверка CSRF-токена
    if (!isset($_POST['user_token']) || !hash_equals($_SESSION['session_token'], $_POST['user_token'])) {
        die('Ошибка: недействительный CSRF-токен');
    }

    // Подготовка входных данных
    $user = trim($_POST['username']);
    $pass = $_POST['password'];

    // Проверка длины имени пользователя
    if (strlen($user) > 25) {
        die('Ошибка: слишком длинное имя пользователя');
    }

    // Хэшируем пароль
    $passHash = password_hash($pass, PASSWORD_BCRYPT);

    // Параметры блокировки
    $total_failed_login = 3; 
    $lockout_time = 15; 
    $account_locked = false; 

    // Подключение к БД и проверка пользователя
    $data = $db->prepare('SELECT failed_login, last_login, password FROM users WHERE user = :user LIMIT 1');
    $data->bindParam(':user', $user, PDO::PARAM_STR);
    $data->execute();
    $row = $data->fetch(PDO::FETCH_ASSOC);

    if ($row) {
        // Проверка на блокировку аккаунта
        if ($row['failed_login'] >= $total_failed_login) {
            $last_login = strtotime($row['last_login']);
            $timeout = $last_login + ($lockout_time * 60);
            $timenow = time();

            if ($timenow < $timeout) {
                die('Аккаунт временно заблокирован. Попробуйте позже.');
            }
        }

        // Проверка пароля
        if (password_verify($pass, $row['password'])) {
            // Успешный вход
            echo '<p>Добро пожаловать, ' . htmlspecialchars($user, ENT_QUOTES, 'UTF-8') . '!</p>';

            // Сброс счетчика неудачных попыток
            $data = $db->prepare('UPDATE users SET failed_login = 0, last_login = NOW() WHERE user = :user LIMIT 1');
            $data->bindParam(':user', $user, PDO::PARAM_STR);
            $data->execute();
        } else {
            // Неверный пароль, увеличиваем количество неудачных попыток
            sleep(rand(2, 4)); // Искусственная задержка для защиты от брутфорса
            $data = $db->prepare('UPDATE users SET failed_login = failed_login + 1 WHERE user = :user LIMIT 1');
            $data->bindParam(':user', $user, PDO::PARAM_STR);
            $data->execute();

            echo '<p>Неверное имя пользователя или пароль.</p>';
        }
    } else {
        // Если пользователь не найден, искусственная задержка
        sleep(rand(2, 4));
        echo '<p>Неверное имя пользователя или пароль.</p>';
    }
}

// Генерация токена для защиты от CSRF
generateSessionToken();

function generateSessionToken() {
    if (empty($_SESSION['session_token'])) {
        $_SESSION['session_token'] = bin2hex(random_bytes(32));
    }
}
?>
```

В вышеуказанном коде были исправлены найденные мной уязвимости, в том числе защита от bruteforce