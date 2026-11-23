# Cores do app a partir da identidade visual da UTFPR

Plano de uma **issue avulsa** do mobile: trocar a cor provisória do tema (o laranja `#E65100`) pelas cores da UTFPR e deixar o app só com o tema claro. O logo do app (o ícone e o splash) continua o que já existe.

Não é um épico. A mudança fica concentrada em `app/theme/` e em meia dúzia de widgets, e cabe num PR só. Dividida em tasks, ela deixaria a `develop` com o app metade laranja e metade amarelo entre um PR e outro.

## 1. Decisões

| Tema                | Decisão                                                                                                                                                                                                                                                                                                                  |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Fonte das cores     | O CSS do portal [utfpr.edu.br](https://www.utfpr.edu.br/) (as variáveis `--ds-*` do design system do site e as classes do HTML), consultado em 23/11/2026. O portal não publica um manual de marca (ver os pontos em aberto).                                                                                            |
| Cores da marca      | O **amarelo** `#FFBE00` (`--ds-yellow-500`, a faixa amarela do topo do portal) e a **tinta** `#18181A` (`--ds-gray-900`, o texto do portal). Os cinzas, os azuis e o verde também vêm do portal. O portal usa ainda o `#FCBC00` nos destaques: a diferença para o `#FFBE00` não aparece, e o app usa um só.              |
| Só o tema claro     | O app deixa de ter o tema escuro e fica claro mesmo com o modo escuro ligado no aparelho: o `AppTheme.dark` e o `darkTheme` do `MaterialApp` saem, e os testes no tema escuro também.                                                                                                                                    |
| Regra do amarelo    | O amarelo **nunca** é cor de texto ou de ícone: sobre a superfície do tema (`#F9F9F9`), o contraste é de 1,58:1, e sobre o branco, de 1,66:1 (o mínimo é 4,5:1 para texto e 3:1 para ícone). Ele é sempre um **fundo**, com a tinta por cima (10,65:1), como na faixa do portal.                                         |
| Botão principal     | Amarelo com o texto em tinta. O `FilledButton` passa a usar o `primaryContainer` e o `onPrimaryContainer`, pelo `filledButtonTheme`. O tema vale também para o `FilledButton.tonal`: os tonais recebem o `AppTheme.tonalButtonStyle` e ficam no cinza (`secondaryContainer`), para o amarelo marcar só a ação principal. |
| Cor de destaque     | O `primary` é a tinta: é a cor dos ícones grandes das telas, dos `TextButton`, do foco dos campos, das caixas de seleção e dos indicadores de carregamento.                                                                                                                                                              |
| Como o tema é feito | `ColorScheme.fromSeed(seedColor: AppColors.yellow, dynamicSchemeVariant: DynamicSchemeVariant.monochrome)`, com `copyWith` nos papéis da marca (seção 3). O `monochrome` gera as superfícies e os contornos em cinza neutro, como os do portal, e o vermelho padrão do Material 3 para os erros.                         |
| Por que não só seed | Com o amarelo como seed e a variante padrão (`tonalSpot`), o Material 3 gera um `primary` mostarda-escuro (o tom 40 do amarelo) e superfícies amareladas: não é a cara da UTFPR.                                                                                                                                         |
| Azul                | O azul dos links do portal (`#005DB7`, `#A9C7FF` e `#001C3A`) vira o `tertiary`: os avisos (e-mail não confirmado e as dicas do "Novo reporte") ficam azuis.                                                                                                                                                             |
| Verde de sucesso    | O Material 3 não tem papel de sucesso. Uma `ThemeExtension` (`SuccessColors`), com o verde do portal, entra para o "Confirmado", a regra da senha atendida e o "ok" do diagnóstico.                                                                                                                                      |
| Status do reporte   | "Em validação" em amarelo (`primaryContainer`), "Confirmado" em verde (`SuccessColors`), "Descartado" no vermelho de erro (`errorContainer`) e "Em acompanhamento" em cinza (`surfaceContainerHighest`). O texto e o ícone continuam dizendo tudo sozinhos (RM26).                                                       |
| Erro                | O vermelho padrão do Material 3 (`#BA1A1A`), já perto do vermelho do portal (`#C7000E`) e com o contraste conferido pelo Material.                                                                                                                                                                                       |
| Logo                | O ícone e o splash continuam os de hoje (o pino branco sobre o laranja `#E65100`), sem mudança nas imagens nem na cor. O laranja deixa de ser a cor do tema e fica só no logo: os comentários do `flutter_launcher_icons.yaml` e do `flutter_native_splash.yaml` param de citar o `AppColors.seed`.                      |
| Onde as cores ficam | Só em `app/theme/`. As telas usam o `colorScheme` ou a `SuccessColors`, nunca `Color(0x...)` nem `Colors.*`. O fundo preto da foto ampliada vira `AppColors.photoBackdrop`, e um teste novo barra as cores fixas fora do tema.                                                                                           |
| Contraste conferido | Um teste do tema confere o contraste de cada par (cor de fundo e cor do conteúdo), para uma troca de cor no futuro não quebrar a leitura. As verificações de acessibilidade das telas (`textContrastGuideline`) continuam valendo.                                                                                       |

## 2. Cores da UTFPR (`AppColors`)

Cada cor guarda, no comentário, de onde veio do portal.

| Nome em `AppColors` | Cor       | Onde aparece no portal                     | Uso no app                                     |
| ------------------- | --------- | ------------------------------------------ | ---------------------------------------------- |
| `yellow`            | `#FFBE00` | `--ds-yellow-500`, a faixa amarela do topo | Botão principal e "Em validação"               |
| `ink`               | `#18181A` | `--ds-gray-900`, o texto das páginas       | `primary` e o texto sobre o amarelo e o cinza  |
| `gray800`           | `#464646` | `--ds-gray-800`                            | `secondary`                                    |
| `gray300`           | `#E4E4E4` | `--ds-gray-300`                            | `secondaryContainer`                           |
| `blue`              | `#005DB7` | Os links e o realce do menu                | `tertiary`                                     |
| `blueLight`         | `#A9C7FF` | O fundo do item do menu em realce          | `tertiaryContainer`                            |
| `navy`              | `#001C3A` | O fundo da barra inferior no modo escuro   | Texto sobre o `tertiaryContainer`              |
| `green900`          | `#006A00` | `--ds-green-900`                           | Verde de sucesso e o texto sobre o fundo verde |
| `green50`           | `#E7F7E5` | `--ds-green-50`                            | Fundo do sucesso                               |
| `photoBackdrop`     | `#000000` | (não é do portal)                          | Fundo da foto ampliada                         |

## 3. Papéis do tema

Os papéis fora da tabela (superfícies, contornos, `inverseSurface`, erros e os `*Fixed`) ficam com o que o `fromSeed` gera. O contraste é o do conteúdo sobre o fundo; nas cores de texto e de ícone (`primary`, `secondary`, `tertiary` e o `success`), é sobre a superfície do tema (`#F9F9F9`).

| Papel                  | Cor       | Contraste                       |
| ---------------------- | --------- | ------------------------------- |
| `primary`              | `#18181A` | 16,84                           |
| `onPrimary`            | `#FFFFFF` | 17,73                           |
| `primaryContainer`     | `#FFBE00` |                                 |
| `onPrimaryContainer`   | `#18181A` | 10,65                           |
| `inversePrimary`       | `#FFBE00` | 7,93 (sobre o `inverseSurface`) |
| `secondary`            | `#464646` | 8,96                            |
| `onSecondary`          | `#FFFFFF` | 9,44                            |
| `secondaryContainer`   | `#E4E4E4` |                                 |
| `onSecondaryContainer` | `#18181A` | 13,94                           |
| `tertiary`             | `#005DB7` | 6,14                            |
| `onTertiary`           | `#FFFFFF` | 6,46                            |
| `tertiaryContainer`    | `#A9C7FF` |                                 |
| `onTertiaryContainer`  | `#001C3A` | 10,02                           |
| `success` (extensão)   | `#006A00` | 6,51                            |
| `onSuccess`            | `#FFFFFF` | 6,86                            |
| `successContainer`     | `#E7F7E5` |                                 |
| `onSuccessContainer`   | `#006A00` | 6,15                            |

O `inversePrimary` é a cor da ação do `SnackBar`: amarelo sobre o fundo escuro do aviso.

## 4. O que muda no código

| Arquivo                                                                                                                                                                            | Mudança                                                                                                                                                                                                                         |
| ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `lib/app/theme/app_colors.dart`                                                                                                                                                    | As cores da seção 2, no lugar da `seed`                                                                                                                                                                                         |
| `lib/app/theme/app_theme.dart`                                                                                                                                                     | Só o `AppTheme.light`, com o `ColorScheme` da seção 3, o `filledButtonTheme` com o `primaryContainer`, o `tonalButtonStyle` e a `SuccessColors`                                                                                 |
| `lib/app/theme/success_colors.dart` (novo)                                                                                                                                         | A `ThemeExtension` com o `copyWith`, o `lerp` e o `SuccessColors.of(context)`                                                                                                                                                   |
| `lib/app/app.dart` e `lib/app/config_error_app.dart`                                                                                                                               | Sem o `darkTheme`                                                                                                                                                                                                               |
| `lib/core/widgets/primary_button.dart`                                                                                                                                             | Carregando, o botão usa o `primaryContainer` e o `onPrimaryContainer` (hoje, o `primary` e o `onPrimary`)                                                                                                                       |
| `lib/features/reports/presentation/widgets/report_status_label.dart`                                                                                                               | As cores dos status da seção 1                                                                                                                                                                                                  |
| `lib/features/auth/presentation/widgets/password_rules.dart`                                                                                                                       | A regra atendida no `success` (hoje, no `primary`, que vira a tinta e fica igual à regra não atendida)                                                                                                                          |
| `lib/features/health/presentation/views/diagnostics_view.dart`                                                                                                                     | O "ok" no `success`                                                                                                                                                                                                             |
| `lib/features/reports/presentation/views/report_detail_view.dart`                                                                                                                  | O `Colors.black` da foto ampliada vira `AppColors.photoBackdrop`                                                                                                                                                                |
| Os 4 `FilledButton.tonal` ("Tirar a foto" e "Ver o reporte" do `new_report_view.dart`, o do `report_location_card.dart` e o "Reenviar e-mail" do `email_verification_notice.dart`) | Com o `AppTheme.tonalButtonStyle`, para continuarem no cinza                                                                                                                                                                    |
| `flutter_launcher_icons.yaml` e `flutter_native_splash.yaml`                                                                                                                       | Só os comentários: o `#E65100` é a cor do logo, e não mais a do tema. As imagens e os arquivos gerados não mudam                                                                                                                |
| `test/support/pump_app.dart`                                                                                                                                                       | Sem o `darkTheme` e sem o parâmetro `themeMode`                                                                                                                                                                                 |
| `test/app/app_test.dart`                                                                                                                                                           | O app fica no tema claro com o sistema no modo escuro, e usa o `ColorScheme` e a `SuccessColors` do tema                                                                                                                        |
| Testes de acessibilidade (19 arquivos)                                                                                                                                             | O laço `for (final themeMode in [ThemeMode.light, ThemeMode.dark])` vira um teste só, no tema claro                                                                                                                             |
| `test/app/theme/` (novo)                                                                                                                                                           | O contraste dos pares da seção 3, com o `Color.computeLuminance` (`app_theme_test.dart`), a busca por `Color(0x` e `Colors.` fora de `lib/app/theme/` (`app_colors_test.dart`) e a `SuccessColors` (`success_colors_test.dart`) |
| `test/core/widgets/primary_button_test.dart`                                                                                                                                       | O botão amarelo com o texto em tinta, ativo e carregando                                                                                                                                                                        |
| `docs/ARCHITECTURE.md`, `docs/TESTING.md` e `README.md`                                                                                                                            | O tema só claro, sem a cor provisória, sem os testes no tema escuro, e o ícone e o splash como o logo do app                                                                                                                    |

---

## 5. Issue

**Título:** `[FEAT] Cores do app a partir da identidade visual da UTFPR`
**Labels:** `Task` e a label da sprint em que ela entrar. Não tem epic.

```markdown
Trocar a cor provisória do tema (o laranja `#E65100`) pelas cores da UTFPR, tiradas do portal [utfpr.edu.br](https://www.utfpr.edu.br/): o amarelo `#FFBE00` e a tinta `#18181A`, com os cinzas, os azuis e o verde do próprio portal. O app fica só com o tema claro, e o logo (ícone e splash) continua o de hoje. O plano completo, com a origem de cada cor e o contraste de cada par, está em `docs/sprints/cores-utfpr.md`.

- **Cores da marca em um lugar só**: `AppColors` com as cores do portal (cada uma com a origem no comentário), e nenhuma `Color(0x...)` ou `Colors.*` fora de `lib/app/theme/`. O fundo preto da foto ampliada vira `AppColors.photoBackdrop`
- **Só o tema claro**: sem o `AppTheme.dark` e sem o `darkTheme` no `MaterialApp` e no `pumpApp`. Os testes de acessibilidade rodam só no tema claro
- **Tema**: `ColorScheme.fromSeed` com o amarelo e a variante `monochrome` (superfícies em cinza neutro e o vermelho padrão nos erros), com os papéis da marca trocados: `primary` em tinta, `primaryContainer` amarelo com a tinta por cima, `secondary` nos cinzas, `tertiary` nos azuis e o `inversePrimary` amarelo na ação do `SnackBar`
- **Botão principal amarelo com o texto em tinta**: `filledButtonTheme` com o `primaryContainer`, e o `PrimaryButton` carregando com as mesmas cores
- **O amarelo nunca é texto nem ícone** (1,66:1 sobre o fundo claro): sempre fundo, com a tinta por cima
- **Verde de sucesso**: `ThemeExtension` `SuccessColors`, usada no "Confirmado", na regra da senha atendida e no "ok" do diagnóstico
- **Status do reporte**: "Em validação" amarelo, "Confirmado" verde, "Descartado" no vermelho de erro e "Em acompanhamento" cinza, com o texto e o ícone de hoje (RM26)
- **Logo sem mudança**: o ícone e o splash continuam o pino branco sobre o laranja. Só os comentários do `flutter_launcher_icons.yaml` e do `flutter_native_splash.yaml` mudam, porque o laranja deixa de ser a cor do tema
- **Testes**: o contraste de cada par do tema (fundo e conteúdo), com no mínimo 4,5:1, e a busca por cores fixas fora de `lib/app/theme/`
- **Docs**: o `ARCHITECTURE.md`, o `TESTING.md` e o `README.md` sem o tema escuro e sem a cor provisória

**Critérios de aceite**

- Nenhuma tela do app usa o laranja (o ícone e o splash continuam com ele)
- Com o modo escuro ligado no aparelho, o app continua no tema claro
- O botão principal é amarelo com o texto em tinta, e continua assim enquanto carrega
- Os quatro status do reporte aparecem com as cores novas na lista e no detalhe
- O teste de contraste do tema passa, e falha quando um par fica abaixo de 4,5:1 (conferir trocando uma cor de propósito, depois desfeito)
- O teste das cores fixas falha com um `Colors.red` numa tela (conferir de propósito, depois removido)
- As verificações de acessibilidade das telas (`textContrastGuideline`) passam
- Prints das telas principais (login, tela inicial, "Novo reporte", detalhe do reporte e "Minha conta") no PR

**Fora do escopo**

Um logo novo, o logo e o nome da UTFPR no app, outra fonte, mudança de layout das telas e o painel web.
```

---

## 6. Pontos em aberto

- **Manual de marca:** o portal não publica o manual de identidade visual da UTFPR, e as cores saíram do CSS do site. Se a Comunicação da UTFPR (ou o professor) passar o manual com os valores oficiais, o ajuste fica só no `AppColors`, e o teste de contraste avisa se algum par deixar de passar.
- **Logo laranja num app amarelo:** o ícone e o splash continuam laranja, e o app abre num laranja que não aparece mais nas telas. Se um dia o logo for para o amarelo, o pino precisa ficar escuro: o branco some no amarelo (1,66:1).
- **Painel web:** se o painel também for seguir as cores da UTFPR, é outra issue, no repositório dele.
