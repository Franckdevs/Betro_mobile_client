// Import des pages
import '../pages/onboarding/welcome_page.dart';
import '../pages/onboarding/email_page.dart';
import '../pages/onboarding/otp_page.dart';
import '../pages/onboarding/intro_slider_page.dart';
import '../pages/onboarding/registration_page.dart';
import '../pages/dashboard/dashboard_page.dart';
import '../pages/dashboard/reservation_page.dart';
import '../pages/dashboard/compagnie_page.dart';
import '../pages/dashboard/parametre_page.dart';
import '../pages/auth/login_page.dart';

class AppRoutes {
  static final routes = {
    '/welcome': (context) => const Welcome(),
    '/email': (context) => const Email(),
    '/otp': (context) => const Otp(),
    '/register': (context) => const Inscription(),
    '/dashboard': (context) => const Dashboard(),
    '/reservation': (context) => const Reservation(),
    '/compagnie': (context) => const Compagnie(),
    '/parametre': (context) => const ParametrePage(),
    '/intro': (context) => const Intro(),
    '/login': (context) => const LoginPage(),
  };
}
