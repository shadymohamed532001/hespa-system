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

نفّذ نسخة يومية مشفرة واحتفظ بنسخة خارج السيرفر. مثال يدوي:

```bash
docker compose --env-file .env.production -f docker-compose.prod.yml exec -T postgres \
  pg_dump -U hesba -d hesba --format=custom > hesba-backup.dump
```

اختبر الاسترجاع دوريًا على قاعدة منفصلة. لا تعتبر النسخة الاحتياطية ناجحة قبل تجربة الاسترجاع.

## نقاط تشغيل مهمة

- لا تضع `.env.production` أو ملفات النسخ الاحتياطي داخل Git.
- اسمح في `CORS_ORIGINS` بدومينات الويب الموثوقة فقط؛ تطبيق سطح المكتب لا يحتاج Origin.
- لا تغيّر `DB_SYNC=false` في الإنتاج.
- راقب محاولات الدخول والأخطاء، وراجع سجل `GET /api/audit-events` بحساب مدير.
- استخدم firewall يسمح فقط بـSSH وHTTP/HTTPS، ويفضل مفاتيح SSH بدل كلمة المرور.
- حدّث صور Docker والحزم دوريًا بعد أخذ نسخة احتياطية وتجربة التحديث.
