# Testes

Testes com o **`flutter_test`** do SDK, fakes escritos à mão para os contratos de repositório (como o `FakeIdentityProvider` do backend) e o **`mocktail`** para o que não compensa ter um fake. Os fluxos do app inteiro ficam em `test/flows/`, com os fakes, e os fluxos contra a API de verdade, em `integration_test/`, com o pacote `integration_test` do SDK.

## Estrutura

| Tipo        | Onde fica           | Padrão de nome           | Roda no CI                            |
| ----------- | ------------------- | ------------------------ | ------------------------------------- |
| Unitário    | `test/`             | `*_test.dart`            | sim                                   |
| Widget      | `test/`             | `*_test.dart`            | sim                                   |
| Fluxo       | `test/flows/`       | `*_flow_test.dart`       | sim                                   |
| Arquitetura | `test/`             | `architecture_test.dart` | sim                                   |
| Integração  | `integration_test/` | `*_test.dart`            | não (precisa da API e de um aparelho) |

A pasta `test/` espelha a `lib/`: o teste de `lib/core/config/app_config.dart` fica em `test/core/config/app_config_test.dart`. No Flutter, os testes ficam fora de `lib/` para não entrarem no app. As exceções são os [fluxos](#fluxos-do-app-inteiro), que passam pelo app inteiro, e o teste do script da [cobertura mínima](#cobertura), que espelha a `tool/`.

```
test/
├── architecture_test.dart       # regra de dependência entre as camadas
├── flutter_test_config.dart     # roda antes de todos os testes: prepara o pt-BR do intl
├── support/                     # pumpApp, fakes e helpers compartilhados
├── app/                         # router, tema e idioma do app
├── core/                        # auth (com o SDK de verdade), config, location, media, network, utils e widgets
├── features/                    # account, auth, health, home, profile e reports
│   └── <feature>/
│       ├── data/                # DTO e repositório (com o FakeHttpAdapter)
│       ├── domain/              # modelos e regras
│       └── presentation/        # controller, ViewModel, View e widgets
├── flows/                       # fluxos do app inteiro, do abrir o app até a última tela
└── tool/                        # o script da cobertura mínima
integration_test/
├── fixtures/                    # a foto de exemplo dos reportes, em Dart
├── support/                     # TestApi, pumpUntilFound, os passos do usuário (app_steps) e a câmera e o GPS falsos
└── *_test.dart                  # fluxos contra a API local
```

## O que testar em cada camada

| Camada                      | Como testar                                                                                                                               |
| --------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| `domain`                    | Teste unitário, instanciando direto, sem Flutter e sem fakes. São as regras puras.                                                        |
| `data` (DTO)                | Teste unitário do `fromJson` com o JSON da API, e do JSON fora do formato (`FormatException`).                                            |
| `data` (repositório)        | Teste unitário com o `FakeHttpAdapter` no lugar da rede: o método e o caminho chamados, o modelo devolvido e as exceções da API.          |
| `presentation` (ViewModel)  | Teste unitário com o `ProviderContainer.test` e o fake do repositório: cada estado e cada ação.                                           |
| `presentation` (controller) | Teste unitário com o `ProviderContainer.test` e o `AuthFakes`: cada transição de estado, os eventos da sessão e as operações atropeladas. |
| `presentation` (View)       | Teste de widget com o `pumpApp` e o fake do repositório: **cada estado da tela** (carregando, erro e sucesso) e a fonte em 200%.          |
| `core/widgets`              | Teste de widget de cada componente, com as verificações de acessibilidade.                                                                |
| `core/network`              | Teste unitário da conversão de cada status com o `FakeHttpAdapter`, e do log, que não pode mostrar nenhum token.                          |
| `core/auth`                 | Teste unitário com o SDK do SuperTokens de verdade e o `FakeSessionApi` no lugar da API: a sessão guardada, a renovação e os eventos.     |

## Convenções

- A instância testada se chama **`sut`** (_system under test_), como no backend.
- Siga o formato **Arrange / Act / Assert**, separando as três etapas com linhas em branco.
- Use `group` com o nome da classe e o teste com a frase do comportamento em português, começando por "deve" (ou "não deve").
- `test` para o que não monta widget e `testWidgets` para o que monta.
- Não deixe `skip` nem testes focados no repositório.

```dart
void main() {
  group('AppConfig', () {
    test('deve remover os espaços e a barra do final', () {
      final sut = AppConfig(apiUrl: ' http://192.168.0.10:3000// ');

      expect(sut.apiUrl, 'http://192.168.0.10:3000');
    });
  });
}
```

## Montando telas: `pumpApp`

O [`pumpApp`](../test/support/pump_app.dart) monta um widget como uma tela do app: `ProviderScope` (com a configuração de teste e os overrides), tema e idioma pt-BR, sem a repetição automática do Riverpod. Um componente solto precisa de um `Scaffold` em volta.

```dart
testWidgets('deve mostrar a mensagem clara com a API desligada', (tester) async {
  final repository = FakeHealthRepository()..error = const NetworkException();

  await tester.pumpApp(
    const DiagnosticsView(),
    overrides: [healthRepositoryProvider.overrideWithValue(repository)],
  );
  await tester.pump();

  expect(find.text(NetworkException.defaultMessage), findsOneWidget);
});
```

| Helper                                                 | Para que serve                                                                                                                                                                                                                                       |
| ------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `tester.pumpApp(widget, overrides:, config:)`          | Uma tela ou um componente, com o tema do app (só claro) e sem as rotas                                                                                                                                                                               |
| `tester.pumpRouter(router, overrides:)`                | O app com as rotas de um `GoRouter` (ex.: o `createRouter()`)                                                                                                                                                                                        |
| `tester.pumpPushed(screen, overrides:, beforePush:)`   | A tela aberta com o `push` por cima de uma tela de baixo (`screenBelow`), para o `context.pop()` dela funcionar. O `beforePush: AuthFakes.startAuth` cria o `AuthController` antes, como o router do app, para a tela que lê o perfil no `initState` |
| `tester.pumpWholeApp(overrides:, observers:)`          | O app inteiro, como o `main`: as rotas, as telas e o `AuthController` ([fluxos](#fluxos-do-app-inteiro))                                                                                                                                             |
| `tester.usePhoneScreen(textScale: 2)`                  | Tela de celular pequeno (360 x 640) com a fonte do sistema em 200%. Volta ao padrão no fim do teste                                                                                                                                                  |
| `tester.signOutAndConfirm()`                           | Toca no "Sair" da tela e confirma no diálogo, como o usuário. Termina com a saída começada: o teste decide quanto esperar                                                                                                                            |
| `openWholeApp(tester, fakes)`                          | O `pumpWholeApp` com os `AuthFakes`, devolvendo as rotas por onde o app passa ([fluxos](#fluxos-do-app-inteiro))                                                                                                                                     |
| `expectBackClosesTheApp(tester)` e `appRouter(tester)` | Confere que o "voltar" do Android fecha o app, e o `GoRouter` do app montado                                                                                                                                                                         |
| `tester.leaveAndComeBack()`                            | O app vai para o segundo plano e volta, passando pelos estados do meio ([cuidados](#cuidados))                                                                                                                                                       |
| `confirmSignOutButton`                                 | O "Sair" de dentro do diálogo de confirmação, que não se confunde com o botão que abre o diálogo                                                                                                                                                     |
| `tester.container()`                                   | O `ProviderContainer` do app montado, do próprio Riverpod: `tester.container().read(authControllerProvider)`                                                                                                                                         |
| `testConfig`                                           | A configuração de teste, com a API em `http://localhost:3000`                                                                                                                                                                                        |

## Fakes e mocks

Um fake usado por um único teste fica no próprio arquivo de teste. Os que servem a vários testes ficam em [`test/support/`](../test/support):

| Fake                         | Substitui                   | Como usar                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| ---------------------------- | --------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `FakeHealthRepository`       | `HealthRepository`          | Defina o `result`, o `error` (lançado na próxima chamada) ou o `pending` (um `Completer`, para o carregando). Confira o `calls`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| `FakeHttpAdapter`            | A rede, dentro do Dio       | `reply(status, body:, headers:)`, `replyText(...)`, `failWith(DioExceptionType...)` ou `throwError(...)`. As requisições feitas ficam em `requests`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| `fakeDio(adapter)`           | O `Dio` do app              | O mesmo `createDio` do app, com o `FakeHttpAdapter` no lugar da rede                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| `AuthFakes`                  | A sessão, o login e a conta | O `FakeSessionManager`, o `FakeAuthRepository`, o `FakeProfileRepository`, o `FakeRegistrationRepository` e o `FakeSessionsRepository` ligados entre si, como no app. `AuthFakes(signedIn: true)` abre com a sessão guardada. Os `overrides` vão no `pumpApp`, no `pumpPushed` ou no `pumpWholeApp`                                                                                                                                                                                                                                                                                                                                                           |
| `FakeSessionManager`         | `SessionManager`            | `hasStoredSession`, `secondFactorPending`, os erros da próxima chamada (`secondFactorError` e `signOutError`) e o `signOutPending`. O `expire()` simula o `UNAUTHORISED` do SDK (RM07). O `signOutEvent = SessionEvent.expired` imita o SDK depois da exclusão da conta, que apaga os tokens como se a sessão tivesse vencido                                                                                                                                                                                                                                                                                                                                 |
| `FakeAuthRepository`         | `AuthRepository`            | O `signInResult`, o `signInError` ou o `signInPending` do próximo login. Os logins feitos ficam em `signInCalls`. No "Esqueci minha senha", o `passwordResetError`, o `passwordResetPending` e o `passwordResetCalls`. No código da segunda etapa, o `verifyLoginCodeError`, o `verifyLoginCodePending`, o `verifyLoginCodeCalls` (o código certo desliga o `secondFactorPending` da sessão), o `resendLoginCodeError` e o `resendLoginCodeCalls`. O resto da sessão vai para o `FakeSessionManager` dele                                                                                                                                                     |
| `FakeProfileRepository`      | `ProfileRepository`         | O `result` (o `clientProfile`, se o teste não trocar), o `error` ou o `pending`. Confira o `calls`. No reenvio do link de confirmação, o `resendError`, o `resendPending` e o `resendCalls`. Na edição dos dados, na troca de senha, na verificação em duas etapas e na exclusão, o `<ação>Error`, o `<ação>Pending` e o `<ação>Calls` (ex.: `updateError`, `changePasswordCalls`, `setMfaPending`, `deleteAccountCalls`). A edição e a verificação devolvem o `result` com a mudança e o guardam, como a API                                                                                                                                                 |
| `FakeRegistrationRepository` | `RegistrationRepository`    | O `result` (o `RegistrationSuccess`, se o teste não trocar), o `error` ou o `pending` do próximo cadastro. Os dados de cada cadastro ficam em `calls`, como iriam para a API                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| `FakeSessionsRepository`     | `SessionsRepository`        | A lista `sessions` (a deste aparelho, a do navegador e uma antiga, sem o IP: `currentSession`, `browserSession` e `unknownSession`), os erros e as esperas de cada chamada (`listError`, `revokeError`, `revokePending`, `revokeOthersError`) e as chamadas feitas. O encerramento tira a sessão da lista, como a API                                                                                                                                                                                                                                                                                                                                         |
| `FakeReportRepository`       | `ReportRepository`          | Os reportes em memória, como a API: os do cidadão (`mine`, do mais novo ao mais antigo), os de outros (`others`) e a resposta do `nearby`. A abertura entra no começo do `mine` (com a mesma `Idempotency-Key`, devolve o mesmo reporte), a edição troca a descrição e a foto (com o id novo, `<id>-nova`), a exclusão tira o reporte e o voto soma a contagem, marca o `votes.mine` e muda o status no limite (o reporte volta sem a distância, como na API). O `othersReport` monta o reporte de outro cidadão, com o `canVote`. Cada método tem o `<ação>Error`, o `<ação>Pending` e o `<ação>Calls` (ex.: `createError`, `listMinePending`, `photoCalls`) |
| `FakePhotoCapture`           | `PhotoCapture`              | A `photo` da próxima câmera (`null` é o cidadão que cancela), o `error`, o `pending` e o `calls`. O `lostPhoto` é a foto que o Android não entregou, devolvida uma vez só                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| `FakeImageCompressor`        | `ImageCompressor`           | Devolve a `photo` (160 x 120 px) para a foto e a `thumbnail` (40 x 30 px) para a miniatura, pelo `maxSide`. O `error`, o `pending` e os pedidos em `calls`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| `FakeLocationService`        | `LocationService`           | Começa com o GPS ligado, a permissão dada e a `campoMouraoPosition` (8 m). O `serviceEnabled`, a `permission`, a `permissionAfterRequest` (a resposta do pedido), a `position`, o `positionError`, o `positionPending` e as chamadas. O `campoMouraoPositionWith(accuracyMeters:, isMocked:)` dá a posição imprecisa ou falsa                                                                                                                                                                                                                                                                                                                                 |
| `ReportFakes`                | Os quatro acima             | Os fakes dos reportes juntos, com os `overrides`, como o `AuthFakes`. O `verifiedAuthFakes()` é o `AuthFakes` com o Client de e-mail confirmado (RM20)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| `FakeSessionApi`             | A API do SuperTokens        | Só nos testes de `core/auth/`, com o SDK de verdade: as respostas do signin pelo `Dio` e da renovação e do signout pelo pacote `http`, com o SharedPreferences em memória                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |

O [`fake_report_repository.dart`](../test/support/fake_report_repository.dart) tem os reportes de exemplo: o `reportJson` (o JSON da seção 5 do plano dos reportes do backend), o `sampleReport` (o mesmo, como modelo), o `sampleReportWith(...)`, o `myReports(n)` (os reportes do cidadão, `reporte-1` o mais novo, com a descrição "Buraco 1") e o `othersReport(distanceMeters:)` (o de outro cidadão, como o `nearby` devolve). As imagens de exemplo ficam no [`sample_images.dart`](../test/support/sample_images.dart): o `samplePhotoJpeg`, o `sampleThumbnailJpeg`, o `sampleJpegWithExif` (com o EXIF, como a câmera grava) e o `samplePng`, todos imagens de verdade, e o `syntheticJpeg(width:, height:, length:, withExif:)`, um JPEG mínimo com o tamanho exato, para os limites da API (a foto de 2 MB em ponto).

O [`fake_profile_repository.dart`](../test/support/fake_profile_repository.dart) também tem os perfis de exemplo: o `clientProfile` (a Maria do `FRONTEND.md` do backend), o `clientProfileJson` (o mesmo, como a API responde), o `adminProfile` (para a RM01) e o `clientProfileWith(name:, phone:, birthDate:, emailVerifiedAt:, mfaEnabled:)`, o Client com um campo trocado. O `emailVerifiedAt` é uma data de confirmação de exemplo, para as telas que exigem o e-mail confirmado.

Todo contrato de repositório novo ganha um fake escrito à mão, que implementa o contrato (`implements HealthRepository`): ele é mais legível que um mock e quebra a compilação quando o contrato muda. O `mocktail` fica para o que não compensa ter um fake, como um callback ou uma classe de um pacote externo:

```dart
class _MockCallback extends Mock {
  void call();
}

final onRetry = _MockCallback();
await tester.pumpApp(Scaffold(body: ErrorView(message: 'Erro', onRetry: onRetry.call)));

await tester.tap(find.text('Tentar de novo'));

verify(onRetry.call).called(1);
```

### Riverpod nos testes

- O fake entra por override: `healthRepositoryProvider.overrideWithValue(fake)`.
- O ViewModel é testado sem tela, com o `ProviderContainer.test(overrides: [...], retry: noAutomaticRetry)`, que se descarta sozinho no fim do teste.
- Os providers de tela são `autoDispose`: no teste sem tela, um `container.listen(provider, (_, _) {})` mantém o provider vivo entre as leituras, como a tela aberta. O `listen` já constrói o provider, então configure o fake antes dele.
- O `retry: noAutomaticRetry` vale também nos testes (o `pumpApp` já usa): sem ele, o Riverpod repetiria a chamada que falhou, e o teste veria o fake ser chamado várias vezes.
- No teste de widget, leia os providers do app montado pelo `tester.container()`, do Riverpod. Não crie um `ProviderContainer` à parte: ele teria outro `AuthController`, e o estado lido não seria o da tela.
- **A tela que fecha:** para conferir o que o ViewModel faz quando a tela fecha no meio de uma chamada, guarde a assinatura do `container.listen` e feche-a (`screen.close()`). O `container.invalidate` não serve: o Riverpod 3 reconstrói o provider com a mesma instância do Notifier, e o `ref.mounted` continua `true`. O provider sem ouvintes é descartado num `Future`, depois das microtasks: espere com o `pumpEventQueue()`, ou, dentro do `fakeAsync`, com o `async.elapse(Duration.zero)`.

### Tempo: `fakeAsync`

A contagem regressiva do 429 (RM04) usa um `Timer.periodic`. No teste sem tela, o `fakeAsync` (do pacote `fake_async`, a mesma versão que o `flutter_test` usa) controla o relógio, sem esperar de verdade:

```dart
fakeAsync((async) {
  unawaited(submit());
  async.flushMicrotasks();

  expect(state().retrySeconds, 3);

  async.elapse(const Duration(seconds: 3));

  expect(state(), const LoginState());
});
```

No `testWidgets`, o relógio já é falso: o `tester.pump(const Duration(seconds: 1))` avança um segundo.

## Fluxos do app inteiro

Os testes de [`test/flows/`](../test/flows) seguem o caminho do usuário de ponta a ponta, do abrir o app até a última tela, como os e2e do backend, mas sem rede: o app inteiro (as rotas, as telas e o `AuthController` de verdade), montado pelo `pumpWholeApp`, com a sessão e os repositórios trocados pelos fakes do `AuthFakes`. Eles rodam no CI, junto com os outros. O fluxo confere o caminho e as regras que dependem de mais de uma tela. Os detalhes de cada tela (cada mensagem, o leitor de tela e a fonte grande) ficam nos testes dela.

| Arquivo                                                                | O que cobre                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| ---------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [`login_flow_test.dart`](../test/flows/login_flow_test.dart)           | Abertura sem sessão → login → tela inicial com os dados. Abertura com a sessão guardada → tela inicial direto, ou, sem rede, erro → "Tentar de novo" ou "Sair". Sessão que não renova → login com o aviso. Sessão pendente da segunda etapa → tela do código. Senha errada → login certo. ADMIN no login → aviso. Segunda etapa no login → tela do código. Sessão acabada na tela inicial → login com o aviso → entrar de novo. "Sair" com e sem conexão |
| [`account_flow_test.dart`](../test/flows/account_flow_test.dart)       | Tela inicial → "Minha conta" → editar os dados → tela inicial com o nome novo, sem buscar o perfil. Trocar a senha com a atual errada (no campo, sem login) e depois a certa. Encerrar outra sessão. Ativar a verificação → "Sair" → login → tela do código → tela inicial. "Sair" da tela do código. Excluir a conta → login com o aviso, e o "voltar" fecha o app                                                                                      |
| [`reports_flow_test.dart`](../test/flows/reports_flow_test.dart)       | Tela inicial → "Novo reporte" → câmera → localização → envio → detalhe → "Meus reportes". Localização imprecisa → "Atualizar localização" → envio. Reporte a menos de 30 m → "É outro buraco" → envio, ou → "Ver o reporte". Sem o e-mail confirmado → aviso com o reenvio → confirmação → câmera. Detalhe → editar → detalhe atualizado. Detalhe → excluir → lista sem o reporte                                                                        |
| [`validation_flow_test.dart`](../test/flows/validation_flow_test.dart) | Tela inicial → "Reportes perto de você" → "Está lá" → confirmação → item marcado, no fim da lista → detalhe com o voto. Voto que chega a 10 → "Confirmado" no detalhe e na lista. Voto longe demais → a mensagem da API. Localização imprecisa no voto → "Atualizar localização" → voto. Sem o e-mail confirmado → aviso → confirmação → voto liberado. "Novo reporte" → "Ver o reporte" → voto no reporte já aberto                                     |
| [`access_flow_test.dart`](../test/flows/access_flow_test.dart)         | Login → "Criar conta" → cadastro → tela inicial com o aviso do e-mail, e o "voltar" fecha o app. E-mail que já tem conta → "Entrar" → login com o e-mail, ou → "Esqueci minha senha" → "voltar" → login. Login automático que falha → login com o aviso → entrar. Login → "Esqueci minha senha" → mensagem → "Voltar ao login". Tela inicial → "Reenviar e-mail" → contagem. Segundo plano → volta com o e-mail confirmado → o aviso some                |

```dart
testWidgets('deve ir direto à tela inicial, sem passar pelo login (RM06)', (tester) async {
  final fakes = AuthFakes(signedIn: true);
  final routes = await _openApp(tester, fakes);

  await tester.pumpAndSettle();

  expect(routes, [AppRoutes.splash, AppRoutes.home]);
});
```

- **O caminho inteiro:** o `openWholeApp`, do [`app_flow.dart`](../test/support/app_flow.dart), devolve as rotas por onde o app passa, na ordem. Comparar a lista inteira confere também a tela que não pode aparecer, como o login na abertura com a sessão guardada. Quem registra as rotas é um `ProviderObserver` (`RouteHistory`), desde a criação do router: com os fakes, a conferência da sessão termina antes de o `pumpWholeApp` voltar, e um ouvinte ligado depois perderia a primeira troca. Ele lê o `GoRouter.state`, que é o da tela do alto da pilha: a tela aberta com o `push` (como o cadastro, por cima do login) entra na lista, e a volta para o login também.
- **O "voltar" do Android:** depois do login, do login automático do cadastro e do "Sair", o `expectBackClosesTheApp` confere que o "voltar" fecha o app, sem voltar para a tela anterior.
- **A regra no nome:** o teste que confere uma regra do app termina com o código dela, como `(RM06)`. O `fvm flutter test --name RM06` roda todos os testes da regra, nas telas, nos ViewModels e nos fluxos.

## Acessibilidade e fonte grande

Os testes dos componentes e das telas passam pelas verificações de acessibilidade do Flutter, no tema do app, que é só claro:

```dart
final semantics = tester.ensureSemantics();
await tester.pumpApp(Scaffold(body: ErrorView(message: message, onRetry: () {})));

await expectLater(tester, meetsGuideline(androidTapTargetGuideline)); // toque de 48 dp
await expectLater(tester, meetsGuideline(labeledTapTargetGuideline)); // botão com rótulo
await expectLater(tester, meetsGuideline(textContrastGuideline));     // contraste do texto
semantics.dispose();
```

As cores do tema têm testes próprios, em [`test/app/theme/`](../test/app/theme). O `app_theme_test.dart` confere o contraste de cada par do tema (o texto ou o ícone sobre o fundo), com no mínimo 4,5:1: uma troca de cor no `AppColors` que quebre a leitura de um par faz o teste falhar, com o nome do par e o contraste. O `app_colors_test.dart` recusa uma cor fixa (`Color(0x...)`, `Color.fromARGB`, `Color.fromRGBO` ou `Colors.*`) fora de `lib/app/theme/`, com o arquivo e a linha. Os dois conferem a própria regra, como o teste de arquitetura: o amarelo como texto e o `Colors.red` numa tela têm de ser acusados.

Toda tela tem um teste com a fonte em 200%: `tester.usePhoneScreen(textScale: 2)` e, depois de montar, `expect(tester.takeException(), isNull)`, que falha se algum texto estourar o espaço.

Para conferir o que o leitor de tela lê e anuncia, compare a semântica do widget com o `isSemantics`, com o `tester.ensureSemantics()` ligado. O `containsSemantics` está obsoleto no Flutter 3.47:

```dart
expect(
  tester.getSemantics(find.descendant(of: passwordField, matching: find.byType(TextField))),
  isSemantics(label: 'Senha', isTextField: true, isObscured: true),
);
expect(tester.getSemantics(find.text(message)), isSemantics(isLiveRegion: true)); // anunciado
```

## Cuidados

- **Rede:** nos testes de widget, o Flutter responde 400 a qualquer requisição HTTP de verdade. Use o `FakeHttpAdapter` ou o fake do repositório.
- **Datas:** o [`flutter_test_config.dart`](../test/flutter_test_config.dart) prepara o pt-BR do `intl` antes de todos os testes, como o `main`. Uma data da API vem em UTC: o teste que confere o horário na tela usa o `toLocal()`, para passar em qualquer fuso.
- **`material_ui`:** o `tester.pageBack()` procura o botão de voltar do `package:flutter/material.dart`, e o app usa o do `material_ui`. Toque no botão direto: `tester.tap(find.byType(BackButton))`.
- **Rótulos fundidos:** o leitor de tela lê um botão como um rótulo só (ex.: "Carregando" e "Entrar"). Para achar uma parte dele, use `find.bySemanticsLabel(RegExp('Carregando'))`.
- **Animações:** o `pumpAndSettle` espera as animações acabarem e não termina enquanto houver um `CircularProgressIndicator` na tela. No estado de carregando, use o `pump`.
- **Puxar para atualizar:** puxe a tela com o `tester.fling(find.byType(SingleChildScrollView), const Offset(0, 300), 1000)`, o mesmo gesto dos testes do `RefreshIndicator` no Flutter, e depois desenhe com um `pump()` e um `pump(const Duration(seconds: 1))`, para a animação do indicador chegar ao `onRefresh`.
- **Segundo plano:** o `AppLifecycleListener` recusa a troca direta de `paused` para `resumed`, e o binding de teste não cria os estados do meio. Use o `tester.leaveAndComeBack()`, do [`app_lifecycle.dart`](../test/support/app_lifecycle.dart), que passa por todos, como no aparelho.
- **Formulários compridos:** o cadastro não cabe na tela de teste (800 x 600). Role até o botão antes de tocar (`tester.ensureVisible`). Na verificação de acessibilidade, use uma tela alta (`tester.view.physicalSize`), com o formulário inteiro à vista: um botão cortado pela rolagem reprovaria o tamanho do toque sem ser um problema da tela.
- **Botão que volta a ficar ativo:** a cor do botão muda com uma animação. Depois da contagem, espere com o `pumpAndSettle()` antes da verificação de contraste, que leria a cor no meio da animação.
- **Gerenciador de senhas:** a tela que fecha (como o cadastro, depois do login automático) termina o contexto do `AutofillGroup` também, sem salvar. Confira o primeiro `TextInput.finishAutofillContext` do log, e não o único.

## Cobertura

```bash
fvm flutter test --coverage
```

O relatório sai em `coverage/lcov.info`, que o CI publica como artefato do job **Qualidade e testes**. Para ver em HTML, com o `lcov` instalado: `genhtml coverage/lcov.info -o coverage/html`.

- O `main.dart` fica fora, pelo comentário `// coverage:ignore-file` no topo. O mesmo comentário serve para qualquer arquivo que só monta o app.
- Os arquivos gerados (`*.g.dart`, `*.freezed.dart`), quando existirem, também ficam fora: o `freezed` já escreve o `// coverage:ignore-file`, e para o `json_serializable` vale a opção `preamble` do `source_gen:combining_builder` no `build.yaml`.
- Só entram no relatório os arquivos que algum teste importa. Um arquivo sem teste nenhum não aparece com 0%: ele some do relatório.

### Cobertura mínima

O CI confere a cobertura mínima de **80% das linhas** em cada grupo com as regras do app, no papel do `coverageThreshold` do Jest no backend:

| Grupo            | Arquivos                                   |
| ---------------- | ------------------------------------------ |
| `domain/`        | `lib/features/*/domain/`                   |
| `data/`          | `lib/features/*/data/`                     |
| ViewModels       | `lib/features/*/presentation/view_models/` |
| `AuthController` | `lib/features/*/presentation/controllers/` |

```bash
fvm flutter test --coverage
fvm dart run tool/check_coverage.dart
```

- A cobertura é a do grupo inteiro, como a de uma pasta no Jest: um arquivo pouco testado pesa contra os outros do grupo.
- Com um grupo abaixo do mínimo, o [`tool/check_coverage.dart`](../tool/check_coverage.dart) lista os arquivos dele, do menos coberto para o mais coberto, e o job **Qualidade e testes** falha. O relatório é publicado antes da conferência, então ele fica no artefato também quando ela falha.
- Um grupo sem nenhum arquivo no relatório também falha: o relatório saiu incompleto, ou o padrão do grupo deixou de achar os arquivos dele.
- O mínimo e os grupos ficam no começo do script. Uma pasta nova com regras (ex.: `presentation/controllers/` de outra feature) já entra no grupo dela pelo padrão.

## Testes de integração

Os testes de `integration_test/` rodam o app inteiro num emulador ou aparelho, com o SDK do SuperTokens e a API de verdade. Eles ficam fora do CI, porque precisariam da API, do SuperTokens Core e de um emulador.

| Arquivo                                                                                  | O que cobre                                                                                                                                                                                                                  |
| ---------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [`diagnostics_test.dart`](../integration_test/diagnostics_test.dart)                     | O atalho do diagnóstico no login e o "ok" do `GET /api/health`                                                                                                                                                               |
| [`login_flow_test.dart`](../integration_test/login_flow_test.dart)                       | Fluxo do Client: cadastro pela API → senha errada → login → tela inicial com os dados do `/users/me` → "Sair"                                                                                                                |
| [`registration_flow_test.dart`](../integration_test/registration_flow_test.dart)         | Cadastro pela tela do app → login automático → tela inicial com o aviso do e-mail → confirmação pelo link do e-mail, lido no Mailpit → volta ao app → o aviso some                                                           |
| [`password_change_flow_test.dart`](../integration_test/password_change_flow_test.dart)   | Troca de senha com a atual errada (o 422 no campo, sem login) e depois a certa → a sessão aberta em outro lugar deixa de renovar → "Sair" → login com a senha nova                                                           |
| [`sessions_flow_test.dart`](../integration_test/sessions_flow_test.dart)                 | Sessões abertas: a deste aparelho, com o `User-Agent` do app, e a de outro lugar → "Encerrar" → ela deixa de renovar                                                                                                         |
| [`second_factor_flow_test.dart`](../integration_test/second_factor_flow_test.dart)       | Ativar a verificação (com o e-mail confirmado pelo `TestApi`) → "Sair" → login → código lido no Mailpit → tela inicial → desativar → login sem o código                                                                      |
| [`reports_flow_test.dart`](../integration_test/reports_flow_test.dart)                   | Com o e-mail confirmado pelo `TestApi`: "Novo reporte" com a foto de exemplo e um ponto de Campo Mourão → detalhe com a foto que volta da API → "Meus reportes" → editar a descrição → excluir → lista vazia                 |
| [`validation_flow_test.dart`](../integration_test/validation_flow_test.dart)             | Dois Clients do `TestApi`: o autor abre o reporte pela API → o outro entra, acha o reporte em "Reportes perto de você", confirma pela tela e vê "1 de 10 confirmações" → o autor entra e vê a confirmação em "Meus reportes" |
| [`account_deletion_flow_test.dart`](../integration_test/account_deletion_flow_test.dart) | Exclusão com a senha errada (no campo) e depois a certa → login com "Sua conta foi excluída." → o login da conta é recusado → o mesmo e-mail e CPF se cadastram de novo                                                      |

### Como rodar

1. Suba a API local na `develop` do backend, com as migrations e o seed rodados (README do backend). O seed cria os papéis no SuperTokens: sem ele, o cadastro do Client responde 500. Os testes da conta precisam da T8 da sprint 4 no backend (a senha de confirmação errada responde 422, e não 401).

   ```bash
   # No repositório do backend. As migrations e o seed, na primeira vez e depois de cada migration nova.
   npm run db:up
   npm run migration:run
   npm run seed
   npm run start:dev
   ```

2. Confira o `http://localhost:3000/api/health` no navegador da máquina e a `API_URL` do `env/dev.json` para o aparelho ([README](../README.md#conectando-à-api-local)). O teste do cadastro lê o e-mail no Mailpit do `docker-compose.yml` do backend, no mesmo endereço da API, na porta 8025: no celular pelo USB, rode também o `adb reverse tcp:8025 tcp:8025`.
3. Se o app do aparelho tiver uma sessão guardada, saia da conta: todos os testes começam no login.
4. Com o emulador aberto ou o celular conectado:

   ```bash
   fvm flutter test integration_test --dart-define-from-file=env/dev.json
   # Só o fluxo do login:
   fvm flutter test integration_test/login_flow_test.dart --dart-define-from-file=env/dev.json
   # No Linux desktop, um arquivo por comando: com a pasta inteira, o segundo arquivo não abre o app.
   fvm flutter test integration_test/sessions_flow_test.dart -d linux --dart-define-from-file=env/dev.json
   ```

### A câmera e o GPS nos testes de integração

O teste dos reportes não tira foto nem lê o GPS: o [`device_fakes.dart`](../integration_test/support/device_fakes.dart) troca a câmera pela foto de exemplo ([`fixtures/report_photo.dart`](../integration_test/fixtures/report_photo.dart), um JPEG de 480 x 360 px em Dart: no aparelho, o teste não lê os arquivos do projeto) e o GPS por um ponto do centro de Campo Mourão, com 8 m de precisão. Os overrides entram pelo `startApp(overrides:)` do `main.dart`. A API, a sessão e o tratamento da foto são de verdade no Android e no iOS. No computador, onde o `flutter_image_compress` não existe, a foto de exemplo vai como está: ela já cabe nos limites da foto e da miniatura.

A API precisa das rotas de `/api/reports` e das migrations dos reportes na base. Fora de Campo Mourão não importa: o ponto é fixo.

### O Client de teste

O [`TestApi`](../integration_test/support/test_api.dart) prepara o cenário pela API, por fora do app (sem o SDK e sem a sessão do aparelho), como o `E2eApp` do backend:

- **Cadastro:** cada execução cria um Client novo pelo `POST /api/clients`, o autocadastro do app, com um e-mail (`maria.app.<id>@reportaai.invalid`) e um CPF que não se repetem. O teste do cadastro pega só os dados (`newClient`) e cadastra pela tela. O e-mail e o CPF são únicos na API, e as falhas de login de um e-mail fixo se somariam até o bloqueio (RN17), como nos testes do backend. O e-mail de verificação do cadastro aparece no Mailpit (`http://localhost:8025`).
- **E-mails:** o `emailVerificationToken(email)` busca no Mailpit (`/api/v1/search`) o e-mail "Confirme o seu e-mail" da conta, esperando até 15 s pela entrega, e lê o token do link `/verificar-email?token=...`. O `confirmEmail(token)` faz o que a página do painel faria: o `POST /api/email-verifications/confirm`, e o `confirmClientEmail(client)` junta os dois. O `loginCode(email, after:)` lê o código do e-mail "Seu código de acesso ao ReportaAi Cm" enviado depois do horário passado (o do toque no "Entrar").
- **Reportes de outro cidadão:** o `openReport(client, ...)` abre um reporte pelo `POST /api/reports`, por fora do app, com a foto de exemplo, como o reporte que o teste da validação confirma pela tela. O `deleteReport(client, id)` o exclui no fim (ignora o 404). Os dois abrem uma sessão só para a chamada.
- **Outra sessão:** o `signIn(client)` abre uma sessão por fora do app, como o `api.http` ou outro aparelho, e o `refreshStatus(refreshToken)` diz se ela ainda renova (200) ou foi encerrada (401), depois da troca de senha ou do "Encerrar" da lista.
- **Exclusão:** no fim, mesmo quando o teste falha, o Client sai pelo `DELETE /api/users/me`, para a base de dev não acumular contas de teste. Para a conta criada pela tela, o `deleteClient(client, ifExists: true)` ignora a conta que não chegou a existir (o teste falhou antes do cadastro, ou a exclusão foi pela tela). Depois da troca de senha, o `password:` e o `fallbackPassword:` cobrem o teste que falhou antes ou depois da troca. Com a verificação em duas etapas ativa (o teste falhou antes de desativá-la), a exclusão conclui a segunda etapa com o código do Mailpit. A exclusão também encerra a sessão que um teste interrompido deixou no aparelho: na abertura seguinte, o app volta ao login com o aviso de sessão expirada.
- **Limite por IP:** cada execução faz um cadastro e três logins (a senha errada, a certa e o da exclusão). O `POST /api/clients` e o signin aceitam 20 requisições por minuto de cada IP (RN18): rodar o teste muitas vezes seguidas esbarra no limite.
- **Erros:** quando a API recusa o cadastro ou a exclusão, o erro diz o status e a mensagem dela, sem o corpo da resposta, que traz o CPF (RM09).

### Esperando a API

Os passos do usuário ficam no [`app_steps.dart`](../integration_test/support/app_steps.dart): o `signInWith`, o `openAccountEntry` (tela inicial → "Minha conta" → a entrada), o `signOutToLogin`, o `tapVisible` (rola até o botão antes do toque), o `typeInto` (toca no campo antes de digitar: no desktop, o campo que perdeu o foco para outro controle, como a caixa de confirmação da exclusão, não recebe o `enterText`) e o `dismissSnackBars` (o aviso de baixo cobre o "Sair" da "Minha conta", e esperar o tempo dele não basta no desktop).

Contra a API de verdade, o `pumpAndSettle` não basta: ele termina quando a tela para de mudar, e a resposta pode chegar depois (no "Sair", a tela espera a API sem nenhuma animação). O `tester.pumpUntilFound(finder, reason:)`, do [`pump_until.dart`](../integration_test/support/pump_until.dart), desenha a tela até o `finder` achar algo, por até 30 segundos, e falha com o `reason`. O `pumpUntilGone` espera o `finder` sumir, e o `pumpUntil(condição)`, uma condição qualquer, como o "Enviar" que fica ativo depois da busca dos reportes perto. O `pumpAndSettle` continua servindo para o que só depende da tela, como abrir o diálogo do "Sair".

### Problemas comuns

| Sintoma                                                                | Causa                                                            | Solução                                                                             |
| ---------------------------------------------------------------------- | ---------------------------------------------------------------- | ----------------------------------------------------------------------------------- |
| "O app não abriu no login"                                             | O aparelho tem uma sessão guardada                               | Saia da conta no app e rode de novo                                                 |
| O cadastro do Client de teste responde 500                             | Faltam as migrations ou o seed na base de dev                    | No backend, `npm run migration:run` e `npm run seed`                                |
| O cadastro responde 429, ou o login mostra "Muitas tentativas"         | O limite por IP, depois de várias execuções seguidas             | Espere 1 minuto                                                                     |
| O teste não acha a API (`DioException` de conexão)                     | A API está fora do ar, ou a `API_URL` não serve para o aparelho  | Confira o `/api/health` e a tabela do [README](../README.md#conectando-à-api-local) |
| "O e-mail de confirmação ... não chegou ao Mailpit"                    | O Mailpit está fora do ar, ou a porta 8025 não chega ao aparelho | `npm run db:up` no backend, e o `adb reverse tcp:8025 tcp:8025` no celular pelo USB |
| A troca de senha ou a exclusão volta ao login com "Sua sessão expirou" | A API está sem a T8 da sprint 4: a senha errada responde 401     | Atualize o backend                                                                  |

### Gravação da tela

A evidência da sprint é a gravação do fluxo no emulador ou no celular, anexada ao PR. Com o aparelho no `adb`:

```bash
adb shell screenrecord /sdcard/fluxo-login.mp4   # Ctrl+C para parar (até 3 minutos)
adb pull /sdcard/fluxo-login.mp4
```

No emulador, o botão de gravação também fica nos controles estendidos (**...** → **Record and Playback**).

## Comandos

| Comando                                                                                              | O que faz                                                      |
| ---------------------------------------------------------------------------------------------------- | -------------------------------------------------------------- |
| `fvm flutter test`                                                                                   | Roda os testes unitários, de widget, de fluxo e de arquitetura |
| `fvm flutter test test/core/config/app_config_test.dart`                                             | Roda um arquivo                                                |
| `fvm flutter test --name "deve remover"`                                                             | Roda os testes cujo nome contém o texto (ex.: `--name RM07`)   |
| `fvm flutter test --coverage`                                                                        | Gera o relatório de cobertura em `coverage/lcov.info`          |
| `fvm dart run tool/check_coverage.dart`                                                              | Confere a cobertura mínima no relatório, como o CI             |
| `fvm flutter test integration_test --dart-define-from-file=env/dev.json`                             | Roda os testes de integração, com a API local no ar            |
| `fvm flutter test integration_test/login_flow_test.dart --dart-define-from-file=env/dev.json`        | Roda só o fluxo do login contra a API local                    |
| `fvm flutter test integration_test/registration_flow_test.dart --dart-define-from-file=env/dev.json` | Roda só o fluxo do cadastro, com a API e o Mailpit no ar       |

Os testes não rodam no pre-commit (lá ficam o `dart format` e o analyzer): eles rodam no CI, em todo PR.
