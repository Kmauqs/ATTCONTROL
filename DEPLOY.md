# Cómo publicar ATTCONTROL

Este archivo explica cómo dejar ATTCONTROL funcionando en la nube y cómo instalar la aplicación en los teléfonos. El uso diario de la app está en `README.md`. Lo que cambió en cada versión está en `WHATSNEW.md`.

ATTCONTROL no se publica en un sitio web. Tiene dos partes:

1. **La nube (Supabase):** cuentas, fichajes, personal, sitios, fotos y carnets.
2. **La aplicación (Flutter):** se instala en Android y, si hay Mac, en iOS.

La versión actual de la app es **1.3.0** (`1.3.0+4` en `pubspec.yaml`).

---

## Qué no se sube a GitHub

Nunca subas claves ni archivos de entorno. En especial:

- `assets/.env` (lo usa la app)
- `.env` o `.env.seed` (los usa el script de carga inicial)
- `SUPABASE_SERVICE_ROLE_KEY` (solo para servidor o scripts; **nunca** en Flutter)
- logs de crash de Android (`android/hs_err_pid*.log`, `android/replay_pid*.log`, `android/.kotlin/errors/`)

En la app solo van la URL del proyecto y la clave **anon** / **publishable**. Esa clave es pública a propósito: la seguridad la dan las reglas de la base de datos.

---

## 1. Dejar lista la nube (Supabase)

Proyecto actual: [ATTCONTROL en el panel de Supabase](https://supabase.com/dashboard/project/tytzhgvhbmkrybtnlyjb)  
URL: `https://tytzhgvhbmkrybtnlyjb.supabase.co`  
Región: `sa-east-1`

Si vas a crear **otro** proyecto, en el panel copia **Project URL** y **anon / publishable key**. No copies la `service_role` a la aplicación.

### Migraciones (base de datos)

Los archivos están en `supabase/migrations/`, en este orden:

| Archivo | Qué hace |
| --- | --- |
| `20260821000000_init_attcontrol.sql` | Tablas, roles y reglas de acceso |
| `20260821000001_seed_catalog.sql` | Sitio, turno y festivos de ejemplo |
| `20260821000002_guard_privileges_geofence.sql` | Impide que alguien se cambie el rol y valida el GPS |
| `20260821000003_guard_skip_service_role.sql` | Permite que los scripts de servidor creen personal |
| `20260821000004_sites_media_geofence.sql` | Varios sitios, excepción de GPS para staff, foto y carnet |

En un proyecto **nuevo**, aplica todas. En el proyecto que ya está en uso, aplica solo las que falten.

Con la [CLI de Supabase](https://supabase.com/docs/guides/cli) (sesión iniciada y proyecto vinculado):

```powershell
npx supabase db push
```

También puedes pegar cada archivo, en orden, en **SQL Editor** del panel.

La migración `...00004...` crea el depósito de archivos `personnel-files` (fotos y PDF del carnet). Si esa migración ya se aplicó, no hay que crear el bucket a mano.

### Funciones en la nube (Edge Functions)

Hay dos funciones. Hay que volver a publicarlas cada vez que cambie el código en `supabase/functions/`.

| Función | JWT | Para qué sirve |
| --- | --- | --- |
| `login-with-identifier` | no se exige | Entrar con documento o correo |
| `create-employee` | sí se exige | Crear o actualizar personal (solo supervisor o administrador) |

```powershell
npx supabase functions deploy login-with-identifier --no-verify-jwt
npx supabase functions deploy create-employee
```

`--no-verify-jwt` en el login es necesario: la persona todavía no tiene sesión cuando pide entrar.

### Carga inicial de personas (opcional)

Si el proyecto está vacío y quieres cargar el listado de `assets/seed/personal.json`:

1. Crea un archivo `.env` (o `.env.seed`) **en la raíz del repo**, no en `assets/`.
2. Pon `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` y `SEED_PASSWORD` (mínimo 8 caracteres).
3. Ejecuta:

```powershell
python scripts/seed_users.py
```

Cada persona entra con su documento y esa contraseña. Después, desde **Personal** en la app, asígnale una contraseña propia.

El correo interno de Auth es `{documento}@users.attcontrol.local`. En la pantalla de inicio se puede escribir el documento o el correo real de la ficha.

---

## 2. Configurar la aplicación

La app lee `assets/.env` al arrancar.

1. Crea `assets/.env` (no está en GitHub).
2. Déjalo así, con los valores del panel:

```
SUPABASE_URL=https://tytzhgvhbmkrybtnlyjb.supabase.co
SUPABASE_ANON_KEY=pega_aqui_la_clave_anon
```

3. No pongas `SUPABASE_SERVICE_ROLE_KEY` en este archivo.

Si `assets/.env` falta o la URL es un placeholder, la app funciona **solo en el teléfono** (SQLite), sin sincronizar con la nube. Para el equipo real hace falta la nube.

---

## 3. Compilar e instalar en Android

En el PC de desarrollo (Windows):

```powershell
flutter pub get
flutter test
flutter run
```

Para un teléfono concreto:

```powershell
flutter devices
flutter run -d ID_DEL_TELEFONO
```

Para generar un APK de prueba:

```powershell
flutter build apk --debug
```

El archivo queda en `build\app\outputs\flutter-apk\app-debug.apk`.

Paquete de la app: `com.attcontrol.attcontrol`.

### Si la compilación se queda sin memoria

Este equipo tiene 12 GB de RAM. En `android/gradle.properties` el heap de Gradle ya está limitado a 1.5 GB. Si vuelve a fallar con *Out of memory* o *insufficient memory*:

```powershell
cd android
.\gradlew.bat --stop
cd ..
flutter clean
flutter pub get
flutter run
```

Cierra otras apps pesadas (navegador con muchas pestañas, otro Android Studio, etc.) antes de volver a compilar.

El aviso de *Kotlin Gradle Plugin (KGP)* de `file_picker`, `mobile_scanner` o `package_info_plus` es informativo: no detiene la compilación.

El APK de depuración se firma con la clave de debug. Para Play Store haría falta una clave de publicación propia y `flutter build appbundle`.

---

## 4. Compilar para iOS

Hace falta un Mac con Xcode, cuenta de Apple y el bundle configurado en Xcode (`ios/Runner`).

```bash
flutter pub get
flutter run
# o
flutter build ipa
```

En el teléfono deben aceptarse ubicación, cámara y galería (textos ya puestos en `ios/Runner/Info.plist`).

---

## 5. Subir una nueva versión de la app

Cuando cambie lo que ve el usuario:

1. Sube `pubspec.yaml` (`version: X.Y.Z+N`).
2. Iguala `lib/core/config/app_version.dart` (`kAppVersion` y `kAppBuildNumber`).
3. Actualiza `README.md` y `WHATSNEW.md`.
4. Si hubo cambios de base de datos o funciones, aplícalos en Supabase **antes** de instalar la app en los teléfonos.
5. Compila, prueba en un dispositivo y reparte el APK (o el IPA).

La versión se ve al iniciar sesión y al tocar el nombre ATTCONTROL en la barra superior.

---

## 6. Comprobar que quedó bien

- Se puede entrar con documento y contraseña.
- Un empleado ficha **dentro** de un sitio autorizado y **no** ficha si está lejos.
- Un supervisor o administrador puede fichar aunque no esté en un sitio.
- En **Personal** se agregan sitios, foto y PDF del carnet; eso se ve después en **Mi carnet**.
- Sin internet, la marca se guarda y se envía al volver la señal.

---

## Dónde está el código

Repositorio: [https://github.com/Kmauqs/ATTCONTROL](https://github.com/Kmauqs/ATTCONTROL)

Rama de publicación: `main`.
