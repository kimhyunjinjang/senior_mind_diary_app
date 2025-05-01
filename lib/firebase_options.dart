import 'package:firebase_core/firebase_core.dart';

class CustomFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    return FirebaseOptions(
      apiKey: 'AIzaSyB1xch9kp4cIgCzf_eeBt9BQt3-guliD08',
      appId: '1:883895428583:android:5fefde824f58c5d8004942',
      messagingSenderId: '883895428583',
      projectId: 'senior-diary-app',
      storageBucket: 'senior-diary-app.firebasestorage.app',
      authDomain: 'your-auth-domain',
    );
  }
}
