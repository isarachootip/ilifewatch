# เพิ่มใน ios/Podfile ภายใน target 'Runner' do ... end
# VeepooBleSDK.framework ต้องใช้สองไลบรารีนี้ (ตาม Podfile ของแอปตัวอย่าง)
pod 'FMDB'
pod 'MJExtension'

# และตั้ง platform อย่างน้อย:
# platform :ios, '13.0'
