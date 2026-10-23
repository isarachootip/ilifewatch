# ITE Watch Care: แอปต้นแบบสำหรับนาฬิกา F520Pro

ระบบรับข้อมูลสุขภาพจากนาฬิกา F520Pro (แพลตฟอร์ม Joeme Fit / Veepoo SDK) เพื่อให้บริการได้ 3 แบบ: ดูแลผู้สูงอายุ ติดตามความดันให้คลินิก และดูแลสุขภาพพนักงาน

```
นาฬิกา F520Pro ──BLE──> แอป Flutter (Android/iOS) ──HTTPS──> Backend (FastAPI) ──> แดชบอร์ดเจ้าหน้าที่
                         └─ ตัวเชื่อม native ไปยัง Veepoo SDK         └─ แจ้งเตือน / webhook (เช่น LINE OA)
```

| โฟลเดอร์ | เนื้อหา | สถานะการตรวจสอบ |
|---|---|---|
| `mobile/lib/` | แอป Flutter: จับคู่นาฬิกา วัดความดัน (ปั๊มลม) วัด ECG พร้อมกราฟสด ซิงค์ข้อมูลย้อนหลัง คิวส่งข้อมูลตอนออฟไลน์ | ยังไม่ได้รัน `flutter analyze` (เครื่องที่ใช้เขียนไม่มี Flutter SDK) |
| `mobile/android/.../VeepooBridge.kt` | ตัวเชื่อม Android ไปยัง SDK | คอมไพล์ผ่านกับไฟล์ .aar จริงของ SDK แล้ว |
| `mobile/ios/Runner/VeepooBridge.swift` | ตัวเชื่อม iOS ไปยัง SDK | เขียนตาม header ของ SDK 2.2 และแอปตัวอย่าง แต่ยังไม่ได้คอมไพล์ (ต้องใช้ Xcode) |
| `backend/` | API, ฐานข้อมูล, กฎแจ้งเตือน, แดชบอร์ดเว็บ | ผ่านการทดสอบ 9 ชุด และเปิดหน้าแดชบอร์ดทดสอบแล้ว |

---

## 1. Backend

```bash
cd backend
python -m venv .venv && source .venv/bin/activate      # Windows: .venv\Scripts\activate
pip install -r requirements.txt
python -m app.seed                                       # สร้างหน่วยงานและบัญชีตัวอย่าง
uvicorn app.main:app --host 0.0.0.0 --port 8000
python -m pytest -q tests                                # รันชุดทดสอบ
```

- เอกสาร API: http://localhost:8000/docs
- แดชบอร์ด: http://localhost:8000/dashboard (บัญชีตัวอย่าง `care@demo.local`, `doctor@demo.local`, `hr@demo.local`, `nurse@demo.local` ใช้รหัสผ่าน `demo1234`)
- รหัสสำหรับเข้าแอป: `CARE0001` / `CLIN0001` / `CORP0001` ทุกรหัสใช้ PIN `123456`

ตั้งค่าสำหรับระบบจริงผ่าน environment ดังนี้: `DATABASE_URL=postgresql+psycopg://...` และ `SECRET_KEY=<สุ่มยาวๆ>`

### สิทธิ์ของแต่ละบทบาท
| บทบาท | ผู้สูงอายุ / คลินิก | องค์กร (พนักงาน) |
|---|---|---|
| `caregiver` (ผู้ดูแล) | ดูรายบุคคล รับแจ้งเตือน | (ไม่ใช้) |
| `clinician` (แพทย์/พยาบาล) | ดูรายบุคคล ตรวจ ECG บันทึกผลอ่าน | ดูรายบุคคลได้ (พยาบาลประจำบริษัท) |
| `admin` | เพิ่มผู้ใช้ ออกรหัส/PIN | เพิ่มผู้ใช้ และดูได้เฉพาะภาพรวม |
| `hr_viewer` | (ไม่ใช้) | ดูได้เฉพาะภาพรวมแบบไม่ระบุตัวตน และซ่อนตัวเลขของกลุ่มที่มีน้อยกว่า 5 คน |

### การแจ้งเตือน (`backend/app/alerts.py`)
เกณฑ์เริ่มต้นมีดังนี้ ความดัน ≥180/110 เป็นระดับวิกฤต, ≥160/100 หรือตัวบน <90 เป็นระดับเตือน, SpO2 <90% ตั้งแต่ 3 ครั้งขึ้นไป และชีพจร >130 หรือ <40 ตั้งแต่ 3 ครั้งขึ้นไป
ระบบแจ้งเตือนเฉพาะข้อมูลที่อายุไม่เกิน 24 ชม. และไม่แจ้งเรื่องเดิมซ้ำภายใน 6 ชม.
หน่วยงานและรายบุคคลปรับเกณฑ์ได้ (`alert_thresholds`) **โดยแพทย์ของหน่วยงานควรเป็นผู้กำหนดเกณฑ์จริง**

---

## 2. แอปมือถือ (Flutter)

ไฟล์ในโฟลเดอร์นี้เป็นส่วนที่เขียนเพิ่มบนโปรเจกต์ Flutter มาตรฐาน ให้สร้างโปรเจกต์ก่อนแล้วจึงคัดลอกไฟล์ลงไป

```bash
cd mobile
flutter create --org com.ite --project-name ite_watch_care --platforms android,ios .
# คำสั่งนี้จะไม่ทับไฟล์ที่มีอยู่แล้ว (lib/, pubspec.yaml, MainActivity.kt, AppDelegate.swift, AndroidManifest.xml)
flutter pub get
flutter analyze
```

### Android
1. คัดลอกไฟล์จากโฟลเดอร์ SDK (`Android/Android_Ble_SDK-master/android_sdk_source/`)
   - `jar_core/*.aar` รวมกับ `jar_base/libcomx-0.5.jar` และ `jar_base/gson-2.2.4.jar` ไปไว้ที่ `mobile/android/app/libs/`
   - โฟลเดอร์ `jniLibs/` ทั้งโฟลเดอร์ไปไว้ที่ `mobile/android/app/src/main/jniLibs/` (**ECG ต้องใช้ไฟล์ในโฟลเดอร์นี้**)
2. เพิ่มบรรทัดสุดท้ายใน `android/app/build.gradle` (หรือ `build.gradle.kts`) ดังนี้
   `apply from: "veepoo-sdk.gradle"` (สำหรับ kts ใช้ `apply(from = "veepoo-sdk.gradle")`)
3. ตั้งค่า `minSdk = 24` และรันด้วยคำสั่ง `flutter run`

### iOS (ต้องใช้ Mac + Xcode)
1. ลากไฟล์ `IOS/iOS_Ble_SDk/iOS_sdk_source/Framework/2.2.XX.15/VeepooBleSDK.framework` เข้า Xcode แล้วตั้งค่า **Embed & Sign**
2. F520Pro ใช้ชิป JL จึงต้องเพิ่ม framework ในโฟลเดอร์ `doc/K系列第三方库/` ด้วย (`JL_BLEKit`, `DFUnits`, `JLDialUnit`, `ZipZap`)
3. เพิ่ม pod ตาม `ios/Podfile.additions.rb` และเพิ่ม key ตาม `ios/Info.plist.additions.xml`
4. เพิ่มไฟล์ `ios/Runner/VeepooBridge.swift` เข้า target Runner แล้วสั่ง Build

### ขั้นตอนที่แอปทำหลังเชื่อมต่อนาฬิกา (`lib/services/sync_service.dart`)
ส่งข้อมูลส่วนตัว (ส่วนสูง น้ำหนัก อายุ เพศ) → อ่านผลที่ผู้ใช้กดวัดบนนาฬิกาเอง → อ่านข้อมูลย้อนหลัง 3 วัน (ชีพจร SpO2 การนอน ความดันอัตโนมัติ) → ส่งขึ้นเซิร์ฟเวอร์
ถ้าส่งไม่สำเร็จ ข้อมูลจะรอในคิวในเครื่องแล้วส่งใหม่รอบหน้า ฝั่ง server กันข้อมูลซ้ำให้

---

## 3. จุดที่ตรวจสอบจาก Bytecode / Javadoc ของ SDK แล้ว และจุดที่ต้องยืนยันกับนาฬิกาจริง

1. **พารามิเตอร์ boolean ของ `startDetectCuffBP`** (Android — **ตรวจสอบจาก Bytecode แล้ว**):
   จากการ decompile `VPOperateManager.startDetectCuffBP` และ `com.veepoo.protocol.operate.vp_t` พารามิเตอร์ boolean ตัวที่ 2 จะถูกใส่ใน `byte[3]` ของคำสั่ง `0x90 0x01 0x05` และสั่งเปิดรับสตรีมข้อมูลดิบระดับโรงงาน (`0x80` PPG80, `0x85` PPG85, `0x89` G-sensor, `0x94` Cuff ADC เข้าสู่ `ppg80Datas`, `ppg85Datas`, `gsensorDatas`, `cuffDatas`) การส่งค่า `false` สำหรับการวัดปกติของผู้ใช้จึงถูกต้องแล้ว
2. **ค่า `EVPCuffBPTestStatus` และ `finished` ใน `onCuffDataChange`** (Android — **ตรวจสอบจาก Bytecode แล้ว**):
   ใน `vp_t.handler(byte[])` ค่า `finished` จะเป็น `true` เมื่อ `byte[5] == 10` (`0x0A`) ส่วน `d.status` แปลงจาก `byte[6] & 0xFF` โดย `0` = `EMPTY` (กำลังวัด/ปั๊มลม), `1` = `SUCCESS` (วัดสำเร็จ), `2..10` และ `253..255` = สถานะผิดพลาด (`POSTURE_ERROR`, `LOOSE`, `NOT_WEAR`, `TIME_OUT`, `HEART_ERROR`, `SLOW_DEFLATION`, `TOO_MUCH_PRESSURE`, `POOR_SIGNAL_QUALITY`, `NOT_REMAINING_STATIONARY`, `CHARGING`, `LOW_POWER`, `DEVICE_BUSY`)
3. **iOS ไม่มีคำสั่งวัดด้วยปั๊มลมแยกต่างหาก** (**ตรวจสอบจาก Header แล้ว / รอทดสอบกับนาฬิกาจริง**):
   ใน `VPPeripheralBaseManage.h` มีเฉพาะ `veepooSDKTestBloodStart:testMode:testResult:` ส่วน `VPManualBloodPressureModel.h` มีพร็อพเพอร์ตี้ `testModel` (`0` = 光电/PPG, `1` = 气囊/Cuff) และ `protocol` (`0` = ความดันปกติ, `1` = ความดันถุงลม) ต้องยืนยันกับผู้ผลิตหรือทดสอบบน iPhone จริงว่าเมื่อสั่ง `veepooSDKTestBloodStart` กับ F520Pro นาฬิกาจะเดินปั๊มลมหรือไม่
4. **`readDeviceManualData`** (Android — **ตรวจสอบจาก Bytecode และ Demo แล้ว**):
   ใน `com.veepoo.protocol.operate.vp_aa` คำสั่ง `0xDE 0x02` จะแปลง `list1` เป็น bitmask 4 ไบต์ใส่ `byte[6..9]` (ชนิดข้อมูลที่ขออ่าน) และแปลง `list2` ใส่ `byte[10..13]` (ชนิดข้อมูลที่อุปกรณ์รองรับ) โดยแอปตัวอย่าง `OperaterActivity.java` ส่งรายการเดียวกันทั้งสองพารามิเตอร์ หรือส่ง `vp.supportManualDetectTypes` เป็นตัวที่สอง ซึ่งตรงกับที่โค้ดใน `VeepooSyncHandler.kt` ใช้งาน
5. **รหัสผ่านเชื่อมต่อนาฬิกา** (**ยืนยันแล้ว**):
   ใช้ค่าเริ่มต้น `0000` ตาม `OperaterActivity.java` และเอกสาร SDK ทั้งฝั่ง Android และ iOS
6. **สถานะการแตะขั้วของ `EcgDetectState`** (Android — **ตรวจพบจาก Javadoc และแก้ไขแล้ว**):
   ตาม Javadoc `EcgDetectState.html` ฟิลด์ `con` (`getCon()`) คือสถานะคำสั่ง ECG (`0` = ไม่รองรับ, `1` = เริ่มวัด, `2` = หยุดวัด) **ไม่ใช่**สถานะการแตะขั้ว ส่วนสถานะการสัมผัสขั้วจริงอยู่ที่ฟิลด์ `wear` (`getWear()` โดย `0` = สัมผัสขั้วผ่าน, `1` = ไม่ได้แตะขั้ว/lead off) และ `hrv == 255` คือค่าว่างที่ไม่ต้องแสดงผล ได้แก้ไขใน `VeepooMeasureHandler.kt` ให้ใช้ `s.wear != 0` สำหรับ `leadOff` เรียบร้อยแล้ว
7. **เวลาใน `OriginData` / `TimeData` และฐานข้อมูล iOS** (**ตรวจสอบจาก Bytecode แล้ว**):
   ใน `TimeData.class` (`setCurrentTime()` และ `toCalendar()`) SDK ใช้ `TimeZone.getDefault()` / `Calendar.getInstance()` ของโทรศัพท์ (เวลาท้องถิ่น) ในการซิงค์เวลากับนาฬิกาและแปลงกลับเป็น epoch วินาที (`getTimestampSeconds()`)

## 4. ข้อควรทราบด้านลิขสิทธิ์และกฎหมาย

- **ฟีเจอร์ที่ต้องซื้อลิขสิทธิ์เพิ่ม**: README ของ SDK ระบุว่า "ระบบประเมินความเสี่ยงโรค/เตือนความเสี่ยงหัวใจ" (HRV Lorenz, หยุดหายใจขณะหลับ, ช่วงออกซิเจนต่ำ, ภาระหัวใจ, ความเสี่ยงจาก ECG) ไม่รวมอยู่ในสิทธิ์ใช้ SDK โค้ดนี้จึง**ไม่ดึงผลวินิจฉัยหรือความเสี่ยงโรค**มาแสดง (`onEcgDetectDiagnosisChange` ถูกเว้นว่างไว้)
- **อย.**: แอปแสดงค่าที่วัดได้และแจ้งเตือนให้เจ้าหน้าที่ติดตาม โดยไม่วินิจฉัยโรค ถ้าจะเพิ่มฟีเจอร์ตีความทางการแพทย์ ควรปรึกษาเรื่องการขึ้นทะเบียนซอฟต์แวร์เครื่องมือแพทย์ก่อน
- **PDPA**: ข้อมูลสุขภาพเป็นข้อมูลอ่อนไหว ระบบมีส่วนรองรับแล้วดังนี้
  - แอปให้ผู้ใช้ติ๊กยินยอมก่อนใช้งาน และ server บันทึกเวลากับเวอร์ชันของความยินยอม
  - บันทึกการเข้าดูข้อมูลรายบุคคลไว้ใน `audit_log`
  - HR เห็นได้เฉพาะข้อมูลภาพรวม
  - webhook ส่งเฉพาะข้อความแจ้งเตือน ไม่ส่งค่าสุขภาพดิบ

  ก่อนเปิดใช้งานจริงยังต้องทำเพิ่ม: นโยบายความเป็นส่วนตัว, สัญญากับหน่วยงาน (ผู้ควบคุม/ผู้ประมวลผลข้อมูล), เก็บข้อมูลในเครื่องแบบเข้ารหัส, เข้ารหัสฐานข้อมูลและไฟล์ ECG, เปิด HTTPS และจำกัด CORS
