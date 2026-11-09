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
├── support/                     # pumpApp e fakes compartilhados
├── app/                         # router, tema e idioma do app
├── core/                        # config, network, utils e widgets
├── features/
│   └── health/
│       ├── data/                # DTO e repositório (com o FakeHttpAdapter)
│       ├── domain/              # modelos
│       └── presentation/        # ViewModel e View
├── flows/                       # fluxos do app inteiro, do abrir o app até a última tela
└── tool/                        # o script da cobertura mínima
integration_test/
├── support/                     # TestApi e pumpUntilFound
└── *_test.dart                  # fluxos contra a API local
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

| Helper                                                    | Para que serve                                                                                           |
| --------------------------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| `tester.pumpApp(widget, overrides:, config:, themeMode:)` | Uma tela ou um componente, sem as rotas. `themeMode: ThemeMode.dark` testa o tema escuro                 |
| `tester.pumpRouter(router, overrides:)`                   | O app com as rotas de um `GoRouter` (ex.: o `createRouter()`)                                            |
| `tester.pumpWholeApp(overrides:, observers:)`             | O app inteiro, como o `main`: as rotas, as telas e o `AuthController` ([fluxos](#fluxos-do-app-inteiro)) |
| `tester.usePhoneScreen(textScale: 2)`                     | Tela de celular pequeno (360 x 640) com a fonte do sistema em 200%. Volta ao padrão no fim do teste      |
| `testConfig`                                              | A configuração de teste, com a API em `http://localhost:3000`                                            |

## Fakes e mocks

Um fake usado por um único teste fica no próprio arquivo de teste. Os que servem a vários testes ficam em [`test/support/`](../test/support):

| Fake                   | Substitui             | Como usar                                                                                                                                                                                                              |
| ---------------------- | --------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `FakeHealthRepository` | `HealthRepository`    | Defina o `result`, o `error` (lançado na próxima chamada) ou o `pending` (um `Completer`, para o carregando). Confira o `calls`                                                                                        |
| `FakeHttpAdapter`      | A rede, dentro do Dio | `reply(status, body:, headers:)`, `replyText(...)`, `failWith(DioExceptionType...)` ou `throwError(...)`. As requisições feitas ficam em `requests`                                                                    |
| `fakeDio(adapter)`     | O `Dio` do app        | O mesmo `createDio` do app, com o `FakeHttpAdapter` no lugar da rede                                                                                                                                                   |
| `AuthFakes`            | A sessão e o login    | O `FakeSessionManager`, o `FakeAuthRepository` e o `FakeProfileRepository` ligados entre si, como no app. `AuthFakes(signedIn: true)` abre com a sessão guardada. Os `overrides` vão no `pumpApp` ou no `pumpWholeApp` |

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

## Fluxos do app inteiro

Os testes de [`test/flows/`](../test/flows) seguem o caminho do usuário de ponta a ponta, do abrir o app até a última tela, como os e2e do backend, mas sem rede: o app inteiro (as rotas, as telas e o `AuthController` de verdade), montado pelo `pumpWholeApp`, com a sessão e os repositórios trocados pelos fakes do `AuthFakes`. Eles rodam no CI, junto com os outros. O fluxo confere o caminho e as regras que dependem de mais de uma tela. Os detalhes de cada tela (cada mensagem, o leitor de tela e a fonte grande) ficam nos testes dela.

| Arquivo                                                      | O que cobre                                                                                                                                                                                                                                                                                                                                                                                                |
| ------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [`login_flow_test.dart`](../test/flows/login_flow_test.dart) | Abertura sem sessão → login → tela inicial com os dados. Abertura com a sessão guardada → tela inicial direto, ou, sem rede, erro → "Tentar de novo" ou "Sair". Sessão que não renova ou pendente da segunda etapa → login com o aviso. Senha errada → login certo. ADMIN ou segunda etapa no login → aviso. Sessão acabada na tela inicial → login com o aviso → entrar de novo. "Sair" com e sem conexão |

```dart
testWidgets('deve ir direto à tela inicial, sem passar pelo login (RM06)', (tester) async {
  final fakes = AuthFakes(signedIn: true);
  final routes = await _openApp(tester, fakes);

  await tester.pumpAndSettle();

  expect(routes, [AppRoutes.splash, AppRoutes.home]);
});
```

- **O caminho inteiro:** o `_openApp` devolve as rotas por onde o app passa, na ordem. Comparar a lista inteira confere também a tela que não pode aparecer, como o login na abertura com a sessão guardada. Quem registra as rotas é um `ProviderObserver`, desde a criação do router: com os fakes, a conferência da sessão termina antes de o `pumpWholeApp` voltar, e um ouvinte ligado depois perderia a primeira troca.
- **O "voltar" do Android:** depois do login e do "Sair", o `_expectBackClosesTheApp` confere que o "voltar" fecha o app, sem voltar para a tela anterior.
- **A regra no nome:** o teste que confere uma regra do app termina com o código dela, como `(RM06)`. O `fvm flutter test --name RM06` roda todos os testes da regra, nas telas, nos ViewModels e nos fluxos.

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

| Arquivo                                                              | O que cobre                                                                                                   |
| -------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------- |
| [`diagnostics_test.dart`](../integration_test/diagnostics_test.dart) | O atalho do diagnóstico no login e o "ok" do `GET /api/health`                                                |
| [`login_flow_test.dart`](../integration_test/login_flow_test.dart)   | Fluxo do Client: cadastro pela API → senha errada → login → tela inicial com os dados do `/users/me` → "Sair" |

### Como rodar

1. Suba a API local na `develop` do backend, com as migrations e o seed rodados (README do backend). O seed cria os papéis no SuperTokens: sem ele, o cadastro do Client responde 500.

   ```bash
   # No repositório do backend. As migrations e o seed, na primeira vez e depois de cada migration nova.
   npm run db:up
   npm run migration:run
   npm run seed
   npm run start:dev
   ```

2. Confira o `http://localhost:3000/api/health` no navegador da máquina e a `API_URL` do `env/dev.json` para o aparelho ([README](../README.md#conectando-à-api-local)).
3. Se o app do aparelho tiver uma sessão guardada, saia da conta: os dois testes começam no login.
4. Com o emulador aberto ou o celular conectado:

   ```bash
   fvm flutter test integration_test --dart-define-from-file=env/dev.json
   # Só o fluxo do login:
   fvm flutter test integration_test/login_flow_test.dart --dart-define-from-file=env/dev.json
   ```

### O Client de teste

O [`TestApi`](../integration_test/support/test_api.dart) prepara o cenário pela API, por fora do app (sem o SDK e sem a sessão do aparelho), como o `E2eApp` do backend:

- **Cadastro:** cada execução cria um Client novo pelo `POST /api/clients`, o autocadastro do app, com um e-mail (`maria.app.<id>@reportaai.invalid`) e um CPF que não se repetem. O e-mail e o CPF são únicos na API, e as falhas de login de um e-mail fixo se somariam até o bloqueio (RN17), como nos testes do backend. O e-mail de verificação do cadastro aparece no Mailpit (`http://localhost:8025`).
- **Exclusão:** no fim, mesmo quando o teste falha, o Client sai pelo `DELETE /api/users/me`, para a base de dev não acumular contas de teste. A exclusão também encerra a sessão que um teste interrompido deixou no aparelho: na abertura seguinte, o app volta ao login com o aviso de sessão expirada.
- **Limite por IP:** cada execução faz um cadastro e três logins (a senha errada, a certa e o da exclusão). O `POST /api/clients` e o signin aceitam 20 requisições por minuto de cada IP (RN18): rodar o teste muitas vezes seguidas esbarra no limite.
- **Erros:** quando a API recusa o cadastro ou a exclusão, o erro diz o status e a mensagem dela, sem o corpo da resposta, que traz o CPF (RM09).

### Esperando a API

Contra a API de verdade, o `pumpAndSettle` não basta: ele termina quando a tela para de mudar, e a resposta pode chegar depois (no "Sair", a tela espera a API sem nenhuma animação). O `tester.pumpUntilFound(finder, reason:)`, do [`pump_until.dart`](../integration_test/support/pump_until.dart), desenha a tela até o `finder` achar algo, por até 30 segundos, e falha com o `reason`. O `pumpAndSettle` continua servindo para o que só depende da tela, como abrir o diálogo do "Sair".

### Problemas comuns

| Sintoma                                                        | Causa                                                           | Solução                                                                             |
| -------------------------------------------------------------- | --------------------------------------------------------------- | ----------------------------------------------------------------------------------- |
| "O app não abriu no login"                                     | O aparelho tem uma sessão guardada                              | Saia da conta no app e rode de novo                                                 |
| O cadastro do Client de teste responde 500                     | Faltam as migrations ou o seed na base de dev                   | No backend, `npm run migration:run` e `npm run seed`                                |
| O cadastro responde 429, ou o login mostra "Muitas tentativas" | O limite por IP, depois de várias execuções seguidas            | Espere 1 minuto                                                                     |
| O teste não acha a API (`DioException` de conexão)             | A API está fora do ar, ou a `API_URL` não serve para o aparelho | Confira o `/api/health` e a tabela do [README](../README.md#conectando-à-api-local) |

### Gravação da tela

A evidência da sprint é a gravação do fluxo no emulador ou no celular, anexada ao PR. Com o aparelho no `adb`:

```bash
adb shell screenrecord /sdcard/fluxo-login.mp4   # Ctrl+C para parar (até 3 minutos)
adb pull /sdcard/fluxo-login.mp4
```

No emulador, o botão de gravação também fica nos controles estendidos (**...** → **Record and Playback**).

## Comandos

| Comando                                                                                       | O que faz                                                      |
| --------------------------------------------------------------------------------------------- | -------------------------------------------------------------- |
| `fvm flutter test`                                                                            | Roda os testes unitários, de widget, de fluxo e de arquitetura |
| `fvm flutter test test/core/config/app_config_test.dart`                                      | Roda um arquivo                                                |
| `fvm flutter test --name "deve remover"`                                                      | Roda os testes cujo nome contém o texto (ex.: `--name RM07`)   |
| `fvm flutter test --coverage`                                                                 | Gera o relatório de cobertura em `coverage/lcov.info`          |
| `fvm dart run tool/check_coverage.dart`                                                       | Confere a cobertura mínima no relatório, como o CI             |
| `fvm flutter test integration_test --dart-define-from-file=env/dev.json`                      | Roda os testes de integração, com a API local no ar            |
| `fvm flutter test integration_test/login_flow_test.dart --dart-define-from-file=env/dev.json` | Roda só o fluxo do login contra a API local                    |

Os testes não rodam no pre-commit (lá ficam o `dart format` e o analyzer): eles rodam no CI, em todo PR.
