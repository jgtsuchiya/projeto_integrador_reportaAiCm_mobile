import 'dart:async';
import 'dart:math' as math;

/// Os segundos inteiros de uma espera, arredondados para cima e com pelo menos 1: o botão não
/// volta antes de a API aceitar de novo, e o `Retry-After: 0` ainda mostra o aviso por um segundo.
int countdownSecondsOf(Duration duration) =>
    math.max(1, (duration.inMilliseconds / Duration.millisecondsPerSecond).ceil());

/// Contagem regressiva de segundos, para o botão que fica desativado por um tempo e volta
/// sozinho, como depois do 429 (RM04) e dos reenvios de e-mail (RM13 e RM14).
///
/// A cada segundo, chama o `onTick` com os segundos que faltam. Com 0, a contagem acabou. Quem a
/// cria chama o [cancel] quando é descartado (no `ref.onDispose`).
final class Countdown {
  new(this._onTick);

  final void Function(int secondsLeft) _onTick;

  Timer? _timer;
  int _secondsLeft = 0;

  /// Começa a contagem de [seconds], no lugar da que estiver rodando.
  void start(int seconds) {
    cancel();
    _secondsLeft = seconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _secondsLeft--;
      if (_secondsLeft <= 0) cancel();
      _onTick(math.max(0, _secondsLeft));
    });
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }
}
