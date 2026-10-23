# งานต่อ: แอป ITE Watch Care (นาฬิกา F520Pro + Veepoo SDK)

## บริบท
โปรเจกต์นี้คือระบบรับข้อมูลสุขภาพจากสมาร์ทวอทช์ **F520Pro** (แอปทางการชื่อ Joeme Fit ใช้ **Veepoo BLE SDK**) เพื่อให้บริการ 3 แบบ: ดูแลผู้สูงอายุ, ติดตามความดันให้คลินิก, ดูแลสุขภาพพนักงาน
โค้ดต้นแบบเขียนเสร็จแล้ว งานของคุณคือ **ทำให้ build และรันได้จริงบนเครื่องนี้ แล้วทดสอบกับนาฬิกาจริง**

## ตำแหน่งไฟล์
- โปรเจกต์: แตกไฟล์ `ite_watch_care.zip` ไว้ที่ `C:\Users\isara\Projects\ite_watch_care` (ถ้ายังไม่ได้แตก ให้แตกก่อน)
- SDK ของผู้ผลิต: `C:\Users\isara\Downloads\Joeme Fit SDK 260626`
  - Android: `Android\Android_Ble_SDK-master\android_sdk_source\` (jar_core, jar_base, jniLibs, apidoc, Demo)
  - iOS: `IOS\iOS_Ble_SDk\iOS_sdk_source\` (Framework\2.2.XX.15, doc\K系列第三方库, Demo)
- **อ่าน `README.md` ในโปรเจกต์ก่อนเริ่ม** มีขั้นตอนติดตั้งและรายการจุดที่ยังไม่ยืนยัน

## โครงสร้าง
- `mobile/` แอป Flutter (Android + iOS)
  - `lib/watch/watch_service.dart` API ฝั่ง Dart คุยกับ native ผ่าน MethodChannel `ite.watch/method` และ EventChannel `ite.watch/events`
  - `android/app/src/main/kotlin/com/ite/ite_watch_care/VeepooBridge.kt` ตัวเชื่อม Android (คอมไพล์ผ่านกับ SDK จริงแล้ว)
  - `ios/Runner/VeepooBridge.swift` ตัวเชื่อม iOS (ยังไม่เคยคอมไพล์)
  - `android/app/veepoo-sdk.gradle` dependency ของ SDK
- `backend/` FastAPI + SQLAlchemy + แดชบอร์ด `/dashboard` (ทดสอบผ่าน 9 ชุดแล้ว)

## งานที่ต้องทำ (ตามลำดับ)

### 1. รัน backend ให้ได้
```
cd backend
python -m venv .venv && .venv\Scripts\activate
pip install -r requirements.txt
python -m app.seed
python -m pytest -q tests
uvicorn app.main:app --host 0.0.0.0 --port 8000
```
เปิด http://localhost:8000/dashboard ล็อกอิน `care@demo.local` / `demo1234` ต้องใช้งานได้

### 2. ทำให้แอป Flutter build ผ่าน (Android ก่อน)
1. ใน `mobile/` รัน `flutter create --org com.ite --project-name ite_watch_care --platforms android,ios .`
   (ไม่ทับไฟล์ที่มีอยู่ ห้ามใช้ `--overwrite`)
2. คัดลอกจาก SDK:
   - `jar_core\*.aar` + `jar_base\libcomx-0.5.jar` + `jar_base\gson-2.2.4.jar` → `mobile\android\app\libs\`
   - โฟลเดอร์ `jniLibs\` ทั้งหมด → `mobile\android\app\src\main\jniLibs\` (ECG ต้องใช้)
3. เพิ่ม `apply from: "veepoo-sdk.gradle"` ท้าย `android/app/build.gradle` (ถ้าเป็น .kts ใช้ `apply(from = "veepoo-sdk.gradle")`) และตั้ง `minSdk = 24`
4. `flutter pub get` → `flutter analyze` → แก้ error ทั้งหมด → `flutter build apk --debug`
5. ถ้า Gradle มีปัญหากับ Kotlin version หรือ dependency ให้ดู `Demo\VpBluetoothSDK\app\build.gradle` และ `build.gradle` ของแอปตัวอย่างใน SDK เป็นต้นแบบ

### 3. ทดสอบกับนาฬิกาจริง (Android)
- ตั้ง Server URL ในหน้าล็อกอินเป็น IP ของเครื่องนี้ เช่น `http://192.168.x.x:8000` ใช้รหัส `CARE0001` PIN `123456`
- ทดสอบตามลำดับ: สแกนเจอนาฬิกา → เชื่อมต่อ (สถานะ ready) → ซิงค์ข้อมูลย้อนหลัง → วัดความดันแบบปั๊มลม → วัด ECG
- หลังแต่ละขั้น เช็คว่าข้อมูลขึ้นในแดชบอร์ด
- เปิด `adb logcat -s VeepooBridge` ดู log ระหว่างทดสอบ

### 4. ยืนยันจุดที่ยังไม่แน่ใจ (ดู README หัวข้อ 3)
ทดสอบกับเครื่องจริงแล้วแก้โค้ดตามผล:
- พารามิเตอร์ boolean ตัวที่ 2 ของ `startDetectCuffBP` (ตอนนี้ส่ง `false`)
- ค่า `EVPCuffBPTestStatus` ระหว่างวัด (ตอนนี้ถือว่า `EMPTY` = กำลังวัด, `SUCCESS` = เสร็จ)
- list ตัวที่ 2 ของ `readDeviceManualData`
- ความหมายของ `EcgDetectState.con` (ตอนนี้ถือว่า 0 = นิ้วไม่ได้แตะขั้ว)
- เวลาจาก `OriginData`/`TimeData` เป็นเวลาท้องถิ่นหรือไม่
- ถ้าเจอปัญหา ให้ค้นวิธีใช้จาก Javadoc ใน `apidoc\` และโค้ดใน `Demo\VpBluetoothSDK\app\src\main\java\com\timaimee\vpdemo\activity\OperaterActivity.java`

### 5. iOS (ทำเมื่อมี Mac)
ทำตาม README หัวข้อ iOS: ใส่ `VeepooBleSDK.framework` (2.2.XX.15) + framework ชิป JL ใน `doc\K系列第三方库\` แบบ Embed & Sign, เพิ่ม pod `FMDB` `MJExtension`, เพิ่ม key ใน Info.plist แล้วคอมไพล์ `VeepooBridge.swift` ให้ผ่าน
ต้องยืนยันว่า `veepooSDKTestBloodStart` ใช้ปั๊มลมของ F520Pro หรือไม่

## ข้อห้าม / กติกา
- **ห้ามเปลี่ยนรูปแบบ event** (key `type` และชื่อ field) ฝั่งเดียว ถ้าเปลี่ยนต้องแก้ทั้ง `VeepooBridge.kt`, `VeepooBridge.swift` และ `watch_service.dart` ให้ตรงกัน
- **ห้ามเพิ่มผลวินิจฉัย/ประเมินความเสี่ยงโรค** (`onEcgDetectDiagnosisChange`, HRV Lorenz, apnea, cardiac load ฯลฯ) เพราะต้องซื้อลิขสิทธิ์จากผู้ผลิตแยก และมีประเด็น อย.
- นาฬิการับคำสั่งได้ทีละคำสั่ง: ทุกคำสั่งที่ใช้เวลานานต้องผ่านคิว `_run()` ใน `WatchService`
- ห้ามส่งข้อมูลสุขภาพดิบไปที่ไหนนอกจาก backend ของเรา (PDPA) และห้าม log ค่าสุขภาพพร้อมชื่อผู้ใช้
- ห้ามแก้ไฟล์ในโฟลเดอร์ SDK ต้นฉบับ ให้คัดลอกมาใช้
- ถ้า `backend` ถูกแก้ ต้องรัน `python -m pytest -q tests` ให้ผ่านทุกครั้ง

## เสร็จเมื่อ
1. `flutter analyze` ไม่มี error และ `flutter build apk --debug` สำเร็จ
2. บนมือถือ Android จริง: เชื่อมต่อนาฬิกา, วัดความดันปั๊มลม, วัด ECG, ซิงค์ย้อนหลัง ได้ครบ และข้อมูลขึ้นในแดชบอร์ด
3. อัปเดต README หัวข้อ 3 ว่าแต่ละจุดยืนยันแล้วได้ผลอย่างไร
4. สรุปสิ่งที่แก้และปัญหาที่ยังค้าง เป็นรายการสั้นๆ
