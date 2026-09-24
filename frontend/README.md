# حِسبة — تطبيق Flutter (سطح مكتب + موبايل)

واجهة Flutter لنظام حِسبة، منظمة بأسلوب feature-first حتى يمكن تطوير كل جزء
بشكل مستقل دون تجميع الشاشات والخدمات في ملفات كبيرة.

المنصات المدعومة: **Windows / macOS / Linux / Android / iOS**.

## هيكل `lib`

```text
lib/
├── app/                 # تشغيل التطبيق والـshell والتنقل الرئيسي
├── core/                # كود مشترك لا يخص feature بعينها
│   ├── network/         # عميل الـAPI ومعالجة أخطاء الشبكة
│   ├── theme/           # الألوان والثيم العام
│   ├── utils/           # أدوات التنسيق العامة
│   └── widgets/         # widgets مشتركة بين أكثر من feature
├── features/            # أجزاء النظام المستقلة
│   ├── accounts/
│   ├── admin/
│   ├── auth/
│   ├── collections/
│   ├── dashboard/
│   ├── ledger/
│   ├── machines/
│   ├── resources/       # السلوك المشترك بين المحافظ والماكينات
│   ├── treasury/
│   └── wallets/
└── main.dart
```

## قواعد الإضافة

- أي شاشة أو منطق يخص مجالًا واحدًا يوضع داخل `features/<feature>`.
- الكود ينتقل إلى `core` فقط عندما يكون عامًا ويستخدمه أكثر من feature.
- `app` مسؤول عن تجميع الـfeatures، ولا يوضع داخله منطق أعمال.
- تجنب إنشاء ملف صفحات مركزي؛ أضف كل صفحة بجوار الـfeature الخاص بها.

## موبايل (Android / iOS)

على الشاشات الأضيق من `900px` يظهر القائمة كـ drawer بدل السايدبار الثابت.

### تشغيل للتطوير

```bash
cd frontend
flutter pub get
flutter devices
flutter run -d android
# أو
flutter run -d ios
```

### بناء نسخة إنتاج

```bash
# Android APK
flutter build apk --release --dart-define=API_BASE_URL=https://hesba.alien-fit.com/api

# Android App Bundle (للـPlay Store)
flutter build appbundle --release --dart-define=API_BASE_URL=https://hesba.alien-fit.com/api

# iOS (يتطلب Xcode + توقيع Apple)
flutter build ipa --release --dart-define=API_BASE_URL=https://hesba.alien-fit.com/api
```

### معرفات الحزم

| المنصة | Application / Bundle ID |
|--------|-------------------------|
| Android | `com.hesba.hesba` |
| iOS | `com.hesba.hesbaDesktop` (نفس تطبيق Firebase الخاص بـ macOS) |

### Firebase على الموبايل

- **iOS**: يستخدم إعدادات Firebase الحالية (`GoogleService-Info.plist`).
- **Android**: Remote Config يعمل مؤقتًا بإعدادات الـweb. لتفعيل FCM كامل على أندرويد سجّل تطبيق Android في Firebase Console ثم نفّذ:

```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=hespa-system
```

وضع ملف `google-services.json` في `android/app/` وأعد البناء.

## التحقق

```bash
flutter analyze
flutter test
```
