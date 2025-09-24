<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Document</title>
</head>
<body>
    <?
    session_start();
    if(isset($_SESSION['errEmail'])){
        echo $_SESSION['errEmail'];
        unset($_SESSION['errEmail']);
    }
    ?>


    <form action="../php/registration.php" method="POST" class=" form d-flex flex-column">
        <div class="mb-3">
            <label for="exampleInputEmail1" class="form-label">Адрес электронной почты</label>
            <input type="text" name="phone" class="form-control" required>
        </div>

        <div class="mb-3">
            <label for="exampleInputPassword1" class="form-label">Пароль (не менее 5 символов)</label>
            <input type="password" name="password" class="form-control" pattern="\w{5,}" required>
        </div>
        <input type="submit" name="btn" class="btn btn-primary">
        <span>Уже есть аккаунт? <a href="auth_page.php">Войти</a></span>
    </form>
</body>
</html>