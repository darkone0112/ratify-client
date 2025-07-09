import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  static final _auth = FirebaseAuth.instance;
  static final _googleSignIn = GoogleSignIn();

  static Future<User?> signInWithEmail(String email, String password) async {
    final userCred = await _auth.signInWithEmailAndPassword(email: email, password: password);
    return userCred.user;
  }

  static Future<User?> registerWithEmail(String email, String password) async {
    final userCred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    return userCred.user;
  }

  static Future<User?> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null;

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCred = await _auth.signInWithCredential(credential);
    return userCred.user;
  }

  static Future<void> signOut() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
  }

  static User? get currentUser => _auth.currentUser;
}
