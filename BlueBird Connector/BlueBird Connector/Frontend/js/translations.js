/**
 * Handle translations of all text visible in the interface.
 */

/**
 * Table of all keys in all supported languages.
 */
const fullTranslationTable = {
  en: {
    say_this: 'Say This',
    find_robots: 'Find Robots',
    finding_robots: 'Finding Robots',
    connected: 'Connected',
    start_programming: 'Start Programming',
    device_disconnected: 'Device (A or B) Disconnected',
    reconnecting: 'Reconnecting',
    connect_dongle: 'Connect Bluetooth Dongle',
    CompassCalibrate: 'Calibrate Compass',
    Update_firmware: 'Update Firmware',
    Connection_Failure: 'Connection Failure'
  },
  ko: {
    say_this: '(Slot 1 = 안녕!) 말하기',
    find_robots: '로봇 찾기',
    finding_robots: '로봇 찾는 중',
    connected: '연결 완료',
    start_programming: '프로그래밍 시작하기',
    device_disconnected: '기기 (A 또는 B) 연결 끊김',
    reconnecting: '다시 연결 중',
    connect_dongle: '블루투스 동글 연결하기',
    CompassCalibrate: '나침반 센서 보정',
    Update_firmware: '펌웨어 업데이트',
    Connection_Failure: '연결 실패'
  },
  de: {
    say_this: 'Sage',
    find_robots: 'Suche Roboter',
    finding_robots: 'Suche Roboter',
    connected: 'Verbunden',
    start_programming: 'Beginne Programmierung',
    device_disconnected: 'Gerät (A oder B) getrennt',
    reconnecting: 'Wiederverbinden',
    connect_dongle: 'Verbinde Bluetooth Dongle',
    CompassCalibrate: 'Kompass kalibrieren',
    Update_firmware: 'Firmware Updaten',
    Connection_Failure: 'Verbindung fehlgeschlagen'
  },
  pt: {
    say_this: 'Diga Isso',
    find_robots: 'Encontre Robôs',
    finding_robots: 'Encontrando Robôs',
    connected: 'Conectado',
    start_programming: 'Iniciar a programação',
    device_disconnected: 'Dispositivo (A ou B) Desconectado',
    reconnecting: 'Reconectando',
    connect_dongle: 'Conecte o Dongle Bluetooth',
    CompassCalibrate: 'Calibrar Bússola',
    Update_firmware: 'Atualizar Firmware',
    Connection_Failure: 'Falha na Conexão'
  },
  fr: {
    say_this: 'Dites ceci',
    find_robots: 'Trouvez des robots',
    finding_robots: 'Trouver des robots',
    connected: 'Connecté',
    start_programming: 'Lancez la programmation',
    device_disconnected: 'Le Périphérique (A ou B) déconnecté',
    reconnecting: 'Reconnecter',
    connect_dongle: 'Connectez le bluetooth dongle',
    CompassCalibrate: 'Calibrer le compas',
    Update_firmware: 'Mettez à Jour le Firmware',
    Connection_Failure: 'Échec de connexion'
  },
  nl: {
    say_this: 'Zeg Dit',
    find_robots: 'Zoek Naar Robots',
    finding_robots: 'Zoeken Naar Robots',
    connected: 'Verbonden',
    start_programming: 'Begin met Programmeren',
    device_disconnected: 'Apparaat (A of B) Losgekoppeld',
    reconnecting: 'Verbinding Opniew Maken',
    connect_dongle: 'Sluit Bluetooth-dongle aan',
    CompassCalibrate: 'Kompas Kalibreren',
    Update_firmware: 'Update Firmware',
    Connection_Failure: 'Verbindingsfout'
  },
  zh_Hans: {
    say_this: '说',
    find_robots: '寻找机器人',
    finding_robots: '寻找机器人中',
    connected: '已连接',
    start_programming: '开始编程',
    device_disconnected: '设备（A或B）已断开连接',
    reconnecting: '重新连接',
    connect_dongle: '连接蓝牙',
    CompassCalibrate: '校准指南针',
    Update_firmware: '更新固件',
    Connection_Failure: '连接失败'
  },
  zh_Hant: {
    say_this: '說',
    find_robots: '尋找機器人',
    finding_robots: '尋找機器人中',
    connected: '已連接',
    start_programming: '開始編程',
    device_disconnected: '設備（A或B）已斷開連接',
    reconnecting: '重新連接',
    connect_dongle: '連接藍牙',
    CompassCalibrate: '校準指南針',
    Update_firmware: '更新固件',
    Connection_Failure: '連接失敗'
  },
  ar: {
    say_this: 'قل هذا',
    find_robots: 'ابحث عن روبوت',
    finding_robots: 'إيجاد روبوت',
    connected: 'متصل',
    start_programming: 'ابدأ البرمجة',
    device_disconnected: 'الجهاز أ أو ب غير متصل',
    reconnecting: 'إعادة الاتصال',
    connect_dongle: 'اتصال عن طريق البلوتوث',
    CompassCalibrate: 'معايرة البوصلة',
    Update_firmware: 'تحديث البرامج الثابتة',
    Connection_Failure: 'فشل الاتصال'
  },
  da: {
    say_this: 'Sig dette',
    find_robots: 'Find robotter',
    finding_robots: 'Finder robotter',
    connected: 'Forbundet',
    start_programming: 'Start programmering',
    device_disconnected: 'Forbindelse til enhed (A eller B) er afbrudt',
    reconnecting: 'Opretter forbindelse igen',
    connect_dongle: 'Forbind bluetooth dongle',
    CompassCalibrate: 'Kalibrér kompas',
    Update_firmware: 'Opdatér Firmware',
    Connection_Failure: 'Forbindelse mislykket'
  },
  he: {
    say_this: 'להגיד',
    find_robots: 'למצוא רובוטים',
    finding_robots: 'מחפשים רובוטים',
    connected: 'מחובר',
    start_programming: 'התחל תכנות',
    device_disconnected: 'עתקן ( א או ב) מנותק',
    reconnecting: 'מחברים מחדש',
    connect_dongle: 'מחברים הדונגל לבלוטוס',
    CompassCalibrate: 'כיול מצפן',
    Update_firmware: 'עדכון קשוחה',
    Connection_Failure: 'חיבור נכשל'
  },
  es: {
    say_this: 'Decir esto',
    find_robots: 'Encontrar robots',
    finding_robots: 'Encontrando robots',
    connected: 'Conectado',
    start_programming: 'Iniciar programacion',
    device_disconnected: 'Dispositivo (A o B) Desconectado',
    reconnecting: 'Reconectando',
    connect_dongle: 'Conectar el dongle del bluethoot',
    CompassCalibrate: 'Calibrar la brujula',
    Update_firmware: 'Actualizar Firmware',
    Connection_Failure: 'Coneccion fallada'
  },
  ca: {
    say_this: 'Digues això',
    find_robots: 'Cerca robots',
    finding_robots: 'Cercant robots',
    connected: 'Connectat',
    start_programming: 'Comença a programar',
    device_disconnected: 'Dispositiu (A o B) desconnectat',
    reconnecting: 'Reconnectant',
    connect_dongle: 'Connecta llapis Bluetooth',
    CompassCalibrate: 'Calibratge de la brúixola',
    Update_firmware: 'Actualitza el Firmware',
    Connection_Failure: 'Error de connexió'
  },
  fi: {
    say_this: 'Sano tämä',
    find_robots: 'Etsi robotteja',
    finding_robots: 'Etsii robotteja',
    connected: 'Yhdistetty',
    start_programming: 'Aloita ohjelmointi',
    device_disconnected: 'Yhteys katkennut laitteeseen (A tai B)',
    reconnecting: 'Yhdistää uudelleen',
    connect_dongle: 'Yhdistä Bluetooth-palikka',
    CompassCalibrate: 'Kalibroi kompassi',
    Update_firmware: 'Päivitä laiteohjelma',
    Connection_Failure: 'Virhe yhdistettäessä'
  },
  sv: {
    say_this: 'Säg detta',
    find_robots: 'Hitta robotar',
    finding_robots: 'Hittar robotar',
    connected: 'Kopplade',
    start_programming: 'Börja programmera',
    device_disconnected: 'Enhet (A eller B) frånkopplad',
    reconnecting: 'Omkopplar',
    connect_dongle: 'Koppla Bluetooth dosa',
    CompassCalibrate: 'Kalibrera kompass',
    Update_firmware: 'Uppdatera Programvara',
    Connection_Failure: 'Problem med kopplingen'
  }
};


/**
 * translateStrings - Translate all strings initially present in the UI, if a
 * translation table has been selected.
 */
function translateStrings() {
  if (translationTable == null) { return; }
  // Set up defaults
  $('#findBtnText').text(" " + translationTable["find_robots"]);
  $('#connection-state').html(translationTable["connected"]);
  $('#start_programming').html(translationTable["start_programming"]);
}

/**
 * setLanguage - Set the app language based on the navigator language. Set to
 * English if the language is not supported. Translate initial strings once set.
 */
function setLanguage() {
  language = window.navigator.language;
  console.log("window.navigator.language = " + language);
  sendMessageToBackend(msgTypes.CONSOLE_LOG, {
    consoleLog: "window.navigator.language = " + language
  })

  if (language.startsWith("zh")) {
    if (language == "zh-TW") { language = "zh_Hant"; } // Specify trad chinese
    else { language = "zh_Hans"; } // Default to simplified chinese for any other variant
  } else {
    language = language.substring(0, 2); // require the 2 letter code.
  }
  // Convert old code for Hebrew to new
  if (language == "iw") { language = "he"; }

  console.log("Language code used: " + language);

  translationTable = fullTranslationTable[language];
  if (translationTable === null) {
    console.log("Language unsupported. Defaulting to English (en)");
    language = "en";
    translationTable = fullTranslationTable[language]; // populate the locale phrases
  }

  console.log("translationTable:");
  console.log(translationTable);

  translateStrings();
}
