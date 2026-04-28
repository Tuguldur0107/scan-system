class S {
  static String _lang = 'en';

  static void setLanguage(String code) => _lang = code;

  // App
  static String get appName => _t('Scan System', 'Скан Систем');

  // Auth
  static String get login => _t('Login', 'Нэвтрэх');
  static String get logout => _t('Logout', 'Гарах');
  static String get username => _t('Username', 'Хэрэглэгчийн нэр');
  static String get password => _t('Password', 'Нууц үг');
  static String get tenantSlug => _t('Organization code', 'Байгууллагын код');
  static String get loginFailed => _t('Login failed', 'Нэвтрэлт амжилтгүй');

  // Scan
  static String get scan => _t('Scan', 'Скан');
  static String get pending => _t('Pending', 'Хүлээгдэж буй');
  static String get history => _t('History', 'Түүх');
  static String get torch => _t('Torch', 'Гэрэл');
  static String get cameraOpened => _t(
    'Camera opened. Align the barcode and tap SCAN.',
    'Камер нээгдлээ. Баркодыг тэгшлээд СКАН дарна уу.',
  );
  static String get noBarcodeDetected => _t(
    'No barcode detected.\nAlign and tap SCAN again.',
    'Баркод илрээгүй.\nТэгшлээд СКАН дахин дарна уу.',
  );
  static String get duplicateScan => _t('Duplicate scan detected.', 'Давхардсан скан.');
  static String addedToPending(String v) => _t('Added: $v', 'Нэмэгдлээ: $v');
  static String get tapScanToOpen => _t('Tap SCAN to open camera.', 'СКАН дарж камер нээнэ үү.');
  static String get alignAndTapScan => _t('Align barcode and tap SCAN.', 'Баркодыг тэгшлээд СКАН дарна уу.');
  static String get tapScanToConfirm => _t('Tap SCAN to confirm.', 'СКАН дарж баталгаажуулна уу.');
  static String get cameraIsClosed => _t('Camera closed.\nTap SCAN to open.', 'Камер хаалттай.\nСКАН дарна уу.');
  static String barcodeDetected(String v) => _t('Detected: $v', 'Илэрлээ: $v');
  static String get closeCamera => _t('Close camera', 'Камер хаах');
  static String get openCamera => _t('OPEN CAMERA', 'КАМЕР НЭЭХ');
  static String get confirmScan => _t('CONFIRM', 'БАТАЛГААЖУУЛАХ');

  // Pending / Sync
  static String get sendAll => _t('Sync all', 'Бүгдийг синк');
  static String get noPendingItems => _t('No pending items.', 'Хүлээгдэж буй зүйл байхгүй.');
  static String get syncing => _t('Syncing...', 'Синк хийж байна...');
  static String get allSynced => _t('All synced', 'Бүгд синк хийгдлээ');
  static String syncPartial(int s, int t) => _t('$s of $t synced.', '$t-ээс $s синк хийгдлээ.');

  // Tasks (was Projects)
  static String get tasks => _t('Tasks', 'Даалгавар');
  static String get selectTask => _t('Select task', 'Даалгавар сонгох');
  static String get createTask => _t('Create task', 'Даалгавар үүсгэх');
  static String get taskName => _t('Task name', 'Даалгаврын нэр');
  static String get noTasks => _t('No tasks yet', 'Даалгавар байхгүй');
  static String get taskClosed => _t('This task is closed', 'Энэ даалгавар хаалттай');
  static String get description => _t('Description', 'Тайлбар');
  static String get data => _t('Data', 'Дата');
  static String get barcodeEpcImport => _t(
        'Barcode → EPC',
        'Баркод → EPC',
      );

  // History
  static String get clearHistory => _t('Clear history?', 'Түүх цэвэрлэх?');
  static String get clear => _t('Clear', 'Цэвэрлэх');
  static String get noHistoryYet => _t('No history yet.', 'Түүх байхгүй.');

  // Admin
  static String get users => _t('Users', 'Хэрэглэгчид');
  static String get dashboard => _t('Dashboard', 'Хянах самбар');
  static String get settings => _t('Settings', 'Тохиргоо');
  static String get tenants => _t('Tenants', 'Байгууллагууд');

  // General
  static String get cancel => _t('Cancel', 'Цуцлах');
  static String get save => _t('Save', 'Хадгалах');
  static String get delete => _t('Delete', 'Устгах');
  static String get edit => _t('Edit', 'Засах');
  static String get ok => _t('OK', 'OK');
  static String get error => _t('Error', 'Алдаа');
  static String get loading => _t('Loading...', 'Ачааллаж байна...');
  static String get working => _t('Working...', 'Ажиллаж байна...');
  static String get sent => _t('Synced', 'Синк хийсэн');

  static String _t(String en, String mn) => _lang == 'mn' ? mn : en;
}
