import 'package:material_ui/material_ui.dart';

/// Cores do app. O Material 3 deriva a paleta inteira (claro e escuro) da [seed].
abstract final class AppColors {
  /// Cor provisória, até a identidade visual do app. O ícone e o splash usam a mesma cor
  /// (`flutter_launcher_icons.yaml` e `flutter_native_splash.yaml`).
  static const seed = Color(0xFFE65100);
}
