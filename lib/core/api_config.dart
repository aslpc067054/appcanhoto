// lib/core/api_config.dart
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;

// class ApiConfig {
//   static const String prodBase   = 'https://loginapi-production-25dc.up.railway.app';
//   static const String localHttp  = 'http://10.0.2.2:5166';  // Android emulador -> API local
//   static const String localHttps = 'https://localhost:7245'; // Desktop/Web -> API local HTTPS

//   static String get base {
//     // Exemplo: sempre usar produção
//     // return prodBase;

//     // Exemplo: lógica por plataforma (descomente se/quando for usar)
//     if (kIsWeb) return prodBase; // web usa prod
//     if (defaultTargetPlatform == TargetPlatform.android) {
//       // emulador Android chamando API local
//       return localHttp;
//     }
//     // desktop/mobile não-Android em dev local (se precisar)
//     return prodBase; // ou localHttps
//   }
// }


class ApiConfig {
  //static const String prodBase = 'https://loginapi-production-25dc.up.railway.app';
  static const String prodBase = 'https://www.expresshow.com';

  static String get base => prodBase;
}
