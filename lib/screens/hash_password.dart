import 'package:bcrypt/bcrypt.dart';

void main() {
  String plainPassword = "password";  // Change to your actual admin password
  String hashedPassword = BCrypt.hashpw(plainPassword, BCrypt.gensalt());

  print("Hashed Password: $hashedPassword");
}
