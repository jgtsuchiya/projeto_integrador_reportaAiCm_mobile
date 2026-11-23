import 'package:material_ui/material_ui.dart';

/// O verde de sucesso, que o Material 3 não tem: o "Confirmado" do reporte, a regra da senha
/// cumprida e o "ok" do diagnóstico. Os nomes seguem os do `ColorScheme`: o [success] é cor de
/// texto e de ícone sobre a superfície, com o [onSuccess] por cima quando é fundo, e o
/// [successContainer] é um fundo, com o [onSuccessContainer] por cima.
///
/// Entra no tema pelo `ThemeData.extensions`, e as telas leem com o [SuccessColors.of].
@immutable
class SuccessColors extends ThemeExtension<SuccessColors> {
  const new({
    required this.success,
    required this.onSuccess,
    required this.successContainer,
    required this.onSuccessContainer,
  });

  final Color success;
  final Color onSuccess;
  final Color successContainer;
  final Color onSuccessContainer;

  /// As cores do tema do [context]. O tema do app (`AppTheme.light`) sempre tem a extensão.
  static SuccessColors of(BuildContext context) {
    final colors = Theme.of(context).extension<SuccessColors>();
    assert(colors != null, 'O tema não tem a SuccessColors: use o AppTheme.light.');
    return colors!;
  }

  @override
  SuccessColors copyWith({
    Color? success,
    Color? onSuccess,
    Color? successContainer,
    Color? onSuccessContainer,
  }) {
    return SuccessColors(
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      successContainer: successContainer ?? this.successContainer,
      onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
    );
  }

  @override
  SuccessColors lerp(SuccessColors? other, double t) {
    if (other == null) return this;
    return SuccessColors(
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      successContainer: Color.lerp(successContainer, other.successContainer, t)!,
      onSuccessContainer: Color.lerp(onSuccessContainer, other.onSuccessContainer, t)!,
    );
  }
}
