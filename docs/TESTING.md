# Testes

Testes com o **`flutter_test`** do SDK, fakes escritos à mão para os contratos de repositório (como o `FakeIdentityProvider` do backend) e o **`mocktail`** para o que não compensa ter um fake. Os fluxos ponta a ponta ficam em `integration_test/`, com o pacote `integration_test` do SDK.

## Estrutura

| Tipo        | Onde fica           | Padrão de nome           | Roda no CI                            |
| ----------- | ------------------- | ------------------------ | ------------------------------------- |
| Unitário    | `test/`             | `*_test.dart`            | sim                                   |
| Widget      | `test/`             | `*_test.dart`            | sim                                   |
| Arquitetura | `test/`             | `architecture_test.dart` | sim                                   |
| Integração  | `integration_test/` | `*_test.dart`            | não (precisa da API e de um aparelho) |

A pasta `test/` espelha a `lib/`: o teste de `lib/core/config/app_config.dart` fica em `test/core/config/app_config_test.dart`. No Flutter, os testes ficam fora de `lib/` para não entrarem no app.

```
test/
├── architecture_test.dart       # regra de dependência entre as camadas
├── flutter_test_config.dart     # roda antes de todos os testes: prepara o pt-BR do intl
├── support/                     # pumpApp e fakes compartilhados
├── app/                         # router, tema e idioma do app
├── core/                        # config, network, utils e widgets
└── features/
    └── health/
        ├── data/                # DTO e repositório (com o FakeHttpAdapter)
        ├── domain/              # modelos
        └── presentation/        # ViewModel e View
```

## O que testar em cada camada

| Camada                     | Como testar                                                                                                                      |
| -------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| `domain`                   | Teste unitário, instanciando direto, sem Flutter e sem fakes. São as regras puras.                                               |
| `data` (DTO)               | Teste unitário do `fromJson` com o JSON da API, e do JSON fora do formato (`FormatException`).                                   |
| `data` (repositório)       | Teste unitário com o `FakeHttpAdapter` no lugar da rede: o método e o caminho chamados, o modelo devolvido e as exceções da API. |
| `presentation` (ViewModel) | Teste unitário com o `ProviderContainer.test` e o fake do repositório: cada estado e cada ação.                                  |
| `presentation` (View)      | Teste de widget com o `pumpApp` e o fake do repositório: **cada estado da tela** (carregando, erro e sucesso) e a fonte em 200%. |
| `core/widgets`             | Teste de widget de cada componente, com as verificações de acessibilidade nos temas claro e escuro.                              |
| `core/network`             | Teste unitário da conversão de cada status com o `FakeHttpAdapter`, e do log, que não pode mostrar nenhum token.                 |

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

| Helper                                                    | Para que serve                                                                                      |
| --------------------------------------------------------- | --------------------------------------------------------------------------------------------------- |
| `tester.pumpApp(widget, overrides:, config:, themeMode:)` | Uma tela ou um componente, sem as rotas. `themeMode: ThemeMode.dark` testa o tema escuro            |
| `tester.pumpRouter(router, overrides:)`                   | O app com as rotas de um `GoRouter` (ex.: o `createRouter()`)                                       |
| `tester.usePhoneScreen(textScale: 2)`                     | Tela de celular pequeno (360 x 640) com a fonte do sistema em 200%. Volta ao padrão no fim do teste |
| `testConfig`                                              | A configuração de teste, com a API em `http://localhost:3000`                                       |

## Fakes e mocks

Um fake usado por um único teste fica no próprio arquivo de teste. Os que servem a vários testes ficam em [`test/support/`](../test/support):

| Fake                   | Substitui             | Como usar                                                                                                                                           |
| ---------------------- | --------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| `FakeHealthRepository` | `HealthRepository`    | Defina o `result`, o `error` (lançado na próxima chamada) ou o `pending` (um `Completer`, para o carregando). Confira o `calls`                     |
| `FakeHttpAdapter`      | A rede, dentro do Dio | `reply(status, body:, headers:)`, `replyText(...)`, `failWith(DioExceptionType...)` ou `throwError(...)`. As requisições feitas ficam em `requests` |
| `fakeDio(adapter)`     | O `Dio` do app        | O mesmo `createDio` do app, com o `FakeHttpAdapter` no lugar da rede                                                                                |

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

## Acessibilidade e fonte grande

Os testes dos componentes e das telas passam pelas verificações de acessibilidade do Flutter, nos temas claro e escuro:

```dart
final semantics = tester.ensureSemantics();
await tester.pumpApp(Scaffold(body: ErrorView(message: message, onRetry: () {})));

await expectLater(tester, meetsGuideline(androidTapTargetGuideline)); // toque de 48 dp
await expectLater(tester, meetsGuideline(labeledTapTargetGuideline)); // botão com rótulo
await expectLater(tester, meetsGuideline(textContrastGuideline));     // contraste do texto
semantics.dispose();
```

Toda tela tem um teste com a fonte em 200%: `tester.usePhoneScreen(textScale: 2)` e, depois de montar, `expect(tester.takeException(), isNull)`, que falha se algum texto estourar o espaço.

## Cuidados

- **Rede:** nos testes de widget, o Flutter responde 400 a qualquer requisição HTTP de verdade. Use o `FakeHttpAdapter` ou o fake do repositório.
- **Datas:** o [`flutter_test_config.dart`](../test/flutter_test_config.dart) prepara o pt-BR do `intl` antes de todos os testes, como o `main`. Uma data da API vem em UTC: o teste que confere o horário na tela usa o `toLocal()`, para passar em qualquer fuso.
- **`material_ui`:** o `tester.pageBack()` procura o botão de voltar do `package:flutter/material.dart`, e o app usa o do `material_ui`. Toque no botão direto: `tester.tap(find.byType(BackButton))`.
- **Rótulos fundidos:** o leitor de tela lê um botão como um rótulo só (ex.: "Carregando" e "Entrar"). Para achar uma parte dele, use `find.bySemanticsLabel(RegExp('Carregando'))`.
- **Animações:** o `pumpAndSettle` espera as animações acabarem e não termina enquanto houver um `CircularProgressIndicator` na tela. No estado de carregando, use o `pump`.

## Cobertura

```bash
fvm flutter test --coverage
```

O relatório sai em `coverage/lcov.info`, que o CI publica como artefato do job **Qualidade e testes**. Para ver em HTML, com o `lcov` instalado: `genhtml coverage/lcov.info -o coverage/html`.

- O `main.dart` fica fora, pelo comentário `// coverage:ignore-file` no topo. O mesmo comentário serve para qualquer arquivo que só monta o app.
- Os arquivos gerados (`*.g.dart`, `*.freezed.dart`), quando existirem, também ficam fora: o `freezed` já escreve o `// coverage:ignore-file`, e para o `json_serializable` vale a opção `preamble` do `source_gen:combining_builder` no `build.yaml`.
- Só entram no relatório os arquivos que algum teste importa. Um arquivo sem teste nenhum não aparece com 0%: ele some do relatório.

## Testes de integração

Os testes de `integration_test/` rodam o app inteiro num emulador ou aparelho, contra a API de verdade. Eles ficam fora do CI, porque precisariam da API, do SuperTokens Core e de um emulador.

```bash
# 1. Suba a API local (README do backend) e confira http://localhost:3000/api/health
# 2. Com o emulador aberto ou o aparelho conectado:
fvm flutter test integration_test --dart-define-from-file=env/dev.json
```

O [`diagnostics_test.dart`](../integration_test/diagnostics_test.dart) abre o app, entra no diagnóstico e espera o "ok" da API. Os fluxos do épico de login (login, tela inicial e "Sair") entram na mesma pasta.

## Comandos

| Comando                                                                  | O que faz                                             |
| ------------------------------------------------------------------------ | ----------------------------------------------------- |
| `fvm flutter test`                                                       | Roda os testes unitários, de widget e de arquitetura  |
| `fvm flutter test test/core/config/app_config_test.dart`                 | Roda um arquivo                                       |
| `fvm flutter test --name "deve remover"`                                 | Roda os testes cujo nome contém o texto               |
| `fvm flutter test --coverage`                                            | Gera o relatório de cobertura em `coverage/lcov.info` |
| `fvm flutter test integration_test --dart-define-from-file=env/dev.json` | Roda os testes de integração, com a API local no ar   |

Os testes não rodam no pre-commit (lá ficam o `dart format` e o analyzer): eles rodam no CI, em todo PR.
