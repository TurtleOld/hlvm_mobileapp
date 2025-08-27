class AppConstants {
  static const String appName = 'HLVM Mobile App';
  static const String appVersion = '1.0.0';

  // API Configuration
  static const String defaultApiBaseUrl = 'https://api.example.com';
  static const int defaultApiTimeout = 120000;

  // API Endpoints
  static const String authTokenEndpoint = '/auth/token/';
  static const String authRefreshEndpoint = '/auth/token/refresh/';
  static const String receiptsListEndpoint = '/receipts/list/';
  static const String receiptsCreateEndpoint = '/receipts/create-receipt/';
  static const String receiptsParseImageEndpoint =
      'https://models.github.ai/inference/chat/completions';
  static const String financeAccountsEndpoint = '/finaccount/list/';

  // Storage Keys
  static const String isLoggedInKey = 'isLoggedIn';
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String serverAddressKey = 'server_address';
  static const String githubTokenKey = 'github_token';

  // Error Messages
  static const String serverAddressRequired =
      'Необходимо указать адрес сервера в настройках';
  static const String sessionExpired =
      'Ваша сессия в приложении истекла, пожалуйста, войдите снова';
  static const String sessionExpiredTitle = 'Сессия истекла';
  static const String unauthorized = 'Неавторизованный доступ';
  static const String networkError = 'Ошибка сети';
  static const String unknownError = 'Неизвестная ошибка';
  static const String sessionExpiredAction = 'Войти снова';

  // UI Constants
  static const double defaultPadding = 16.0;
  static const double defaultSpacing = 8.0;
  static const Duration snackBarDuration = Duration(seconds: 3);
  static const Duration navigationDelay = Duration(milliseconds: 500);
}
