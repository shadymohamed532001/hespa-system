# تشغيل حِسبة بأمان على السيرفر

التركيب المقترح هو: الإنترنت ← Nginx/Caddy مع HTTPS ← API على `127.0.0.1:3000` ← PostgreSQL داخل شبكة Docker غير مكشوفة.

## أول تشغيل

1. انسخ ملف الإعدادات واملأ القيم الفارغة بأسرار جديدة وقوية:

   ```bash
   cp .env.production.example .env.production
   openssl rand -base64 48
   ```

   استخدم الناتج لـ`JWT_SECRET`، واختر كلمات مرور مختلفة لـ`DB_PASSWORD` و`BOOTSTRAP_ADMIN_PASSWORD`. لا تستخدم `demo` أو `shix` في الإنتاج.

2. شغّل الحاويات:

   ```bash
   docker compose --env-file .env.production -f docker-compose.prod.yml up -d --build
   ```

   الـAPI يشغّل الـmigrations قبل كل تشغيل. عند أول تشغيل فقط ينشئ المدير المحدد في `BOOTSTRAP_ADMIN_*` إذا لم يكن هناك مدير فعّال. بعد التأكد من الدخول، احذف كلمة مرور المدير من `.env.production` وأعد تشغيل الـAPI.

3. اربط Nginx أو Caddy بـ`http://127.0.0.1:3000`، وفَعّل شهادة TLS، ولا تفتح منفذ PostgreSQL في جدار الحماية. اجعل تطبيق Flutter يستخدم رابط HTTPS، مثل:

   ```bash
   flutter build windows --release --dart-define=API_BASE_URL=https://api.example.com/api
   ```

## النسخ الاحتياطي

نفّذ نسخة يومية مشفرة واحتفظ بنسخة خارج السيرفر:

```bash
export BACKUP_ENCRYPTION_PASSWORD='كلمة-مرور-طويلة-خارج-ملف-Git'
./scripts/backup.sh
./scripts/restore-test.sh ./backups/hesba-YYYYMMDDTHHMMSSZ.dump.enc
```

`backup.sh` يشفر النسخة بـAES-256 ويحفظ checksum ويحذف النسخ الأقدم من 30 يومًا افتراضيًا. `restore-test.sh` ينشئ قاعدة مؤقتة ويجرب الاسترجاع ثم يحذفها. لا تعتبر النسخة ناجحة قبل هذا الاختبار.

مثال cron يومي (مرّر كلمة التشفير من secret manager أو ملف صلاحياته `600`، وليس من Git):

```cron
15 2 * * * cd /srv/hesba && BACKUP_ENCRYPTION_PASSWORD='...' ./scripts/backup.sh >> /var/log/hesba-backup.log 2>&1
```

## المراقبة

- نقطة الفحص العامة: `GET /api/health` وتتحقق من اتصال PostgreSQL.
- Docker يفحص الـAPI كل 15 ثانية ويعيد تشغيله عند فشل العملية، مع تدوير logs عند 10MB والاحتفاظ بخمسة ملفات.
- اربط أداة المراقبة بالأمر `./scripts/monitor-health.sh` أو بالرابط مباشرة، ونبّه عند أي exit code غير صفر.

## بناء تطبيقات سطح المكتب

- macOS: `./packaging/build-macos-dmg.sh`
- Linux: `./packaging/build-linux-deb.sh`
- Windows: ابنِ Flutter ثم شغّل Inno Setup على `packaging/windows/hesba.iss`.
- إنشاء tag بالشكل `v1.1.0` يشغّل workflow الإصدار ويرفع DMG وEXE وDEB إلى GitHub Release. عرّف `API_BASE_URL` في Repository Variables قبل الإصدار.

## نقاط تشغيل مهمة

- لا تضع `.env.production` أو ملفات النسخ الاحتياطي داخل Git.
- اسمح في `CORS_ORIGINS` بدومينات الويب الموثوقة فقط؛ تطبيق سطح المكتب لا يحتاج Origin.
- لا تغيّر `DB_SYNC=false` في الإنتاج.
- راقب محاولات الدخول والأخطاء، وراجع سجل `GET /api/audit-events` بحساب مدير.
- استخدم firewall يسمح فقط بـSSH وHTTP/HTTPS، ويفضل مفاتيح SSH بدل كلمة المرور.
- حدّث صور Docker والحزم دوريًا بعد أخذ نسخة احتياطية وتجربة التحديث.
