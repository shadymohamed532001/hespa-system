import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// `dev` talks to the local API and `hesba_dev`.
/// `prod` talks to the live shop API.
enum AppFlavor { dev, prod }

AppFlavor get appEnvironment {
  switch (appFlavor) {
    case 'prod':
    case 'production':
      return AppFlavor.prod;
    case 'dev':
    case 'development':
      return AppFlavor.dev;
    default:
      return kReleaseMode ? AppFlavor.prod : AppFlavor.dev;
  }
}

bool get isProductionFlavor => appEnvironment == AppFlavor.prod;

const productionApiBaseUrl = 'https://hesba.alien-fit.com/api';
const developmentApiBaseUrl = 'http://127.0.0.1:3000/api';

String get flavorApiBaseUrl =>
    isProductionFlavor ? productionApiBaseUrl : developmentApiBaseUrl;
