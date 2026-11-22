# Guia de contribuição

Este projeto segue o **Git Flow**, com commits no padrão **Conventional Commits**, com as mesmas regras do [backend](https://github.com/jgtsuchiya/projeto_integrador_reportaAiCm_backend/blob/develop/CONTRIBUTING.md). As regras abaixo são verificadas automaticamente pelos hooks do Husky e pela proteção de branches no GitHub.

## Fluxo de branches

```
feature/12-...    ●──●
                 /    \  (squash)
develop   ──●───●──────●──────────────●────────────●──
                        \            ↑ back-merge  ↑ back-merge
release/0.1.0            ●──●        │             │
                             \       │             │
main      ──●─────────────────●──────┘──────●──────┘──
                           v0.1.0     \    / v0.1.1
hotfix/31-...                          ●──●
```

### Branches permanentes

| Branch    | Papel                                                                        | Recebe merge de                                                                                       |
| --------- | ---------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| `main`    | Código publicado. Cada merge gera uma tag de versão.                         | `release/*` e `hotfix/*`                                                                              |
| `develop` | Integração do que foi concluído na sprint. É a branch padrão do repositório. | `feature/*`, `fix/*` e as demais branches de trabalho, além do back-merge de `release/*` e `hotfix/*` |

Nenhuma das duas aceita push direto. Toda mudança entra por Pull Request.

### Branches de trabalho

Formato: **`<tipo>/<nº da issue>-<descricao-em-kebab-case>`**, em letras minúsculas e sem acentos.

| Tipo        | Uso                                      | Sai de    | Volta para                          |
| ----------- | ---------------------------------------- | --------- | ----------------------------------- |
| `feature/`  | Nova funcionalidade                      | `develop` | `develop`                           |
| `fix/`      | Correção de bug ainda não lançado        | `develop` | `develop`                           |
| `refactor/` | Refatoração sem mudança de comportamento | `develop` | `develop`                           |
| `test/`     | Criação ou ajuste de testes              | `develop` | `develop`                           |
| `docs/`     | Documentação                             | `develop` | `develop`                           |
| `chore/`    | Configuração, dependências e build       | `develop` | `develop`                           |
| `release/`  | Preparação de versão: `release/<x.y.z>`  | `develop` | `main`, com back-merge em `develop` |
| `hotfix/`   | Correção urgente em produção             | `main`    | `main`, com back-merge em `develop` |

Exemplos: `feature/12-tela-de-reporte`, `fix/15-corrige-mascara-do-cpf`, `chore/2-git-flow`, `release/0.1.0`.

Toda branch de trabalho está ligada a uma issue. Se a issue não existir, crie-a antes.

## Dia a dia: desenvolvendo uma issue

```bash
git switch develop
git pull
git switch -c feature/12-tela-de-reporte

# ... desenvolva, com commits pequenos no padrão abaixo ...

# antes de abrir o PR, as mesmas verificações do CI:
dart format .
fvm flutter analyze --fatal-infos
fvm flutter test

git push -u origin feature/12-tela-de-reporte
# Abra o PR para a develop no GitHub
```

Se a `develop` avançar enquanto você trabalha, atualize a sua branch antes de pedir revisão:

```bash
git fetch origin
git rebase origin/develop           # ou: git merge origin/develop
git push --force-with-lease          # só depois de um rebase
```

Se o `pubspec.lock` mudar na `develop`, rode `fvm flutter pub get` depois de atualizar a branch.

## Releases e hotfixes

As versões seguem o **SemVer** (`MAJOR.MINOR.PATCH`). Enquanto o projeto estiver em `0.x`, cada sprint entregue incrementa o `MINOR`.

A versão fica no `version` do [pubspec.yaml](pubspec.yaml), no formato `<versão>+<build>` (ex.: `0.2.0+2`). O número depois do `+` é o `versionCode` do Android e o `CFBundleVersion` do iOS: ele sobe a cada versão gerada, porque as lojas recusam um número repetido.

**Release, ao final da sprint:**

1. Crie `release/0.2.0` a partir da `develop`.
2. Na branch de release, faça apenas ajustes finais: a versão no `pubspec.yaml` e correções pequenas.
3. Abra um PR de `release/0.2.0` para a `main`. Depois do merge, crie a tag `v0.2.0` na `main`.
4. Abra um PR de `main` para `develop` (back-merge), para levar os ajustes da release de volta à `develop`.

**Hotfix:** siga o mesmo fluxo, partindo da `main` (`hotfix/31-corrige-login`) e incrementando o `PATCH` (`v0.2.1`).

## Commits

Padrão [Conventional Commits](https://www.conventionalcommits.org/pt-br/v1.0.0/), validado pelo **commitlint** no hook `commit-msg`:

```
<tipo>(<escopo opcional>): <descrição no imperativo, em minúsculas>

<corpo opcional: o que mudou e por quê>

<rodapé opcional: Closes #12, BREAKING CHANGE: ...>
```

| Tipo       | Quando usar                                                          |
| ---------- | -------------------------------------------------------------------- |
| `feat`     | Nova funcionalidade                                                  |
| `fix`      | Correção de bug                                                      |
| `refactor` | Mudança de código sem alterar comportamento                          |
| `perf`     | Melhoria de performance                                              |
| `test`     | Testes                                                               |
| `docs`     | Documentação                                                         |
| `style`    | Formatação, sem mudança de lógica                                    |
| `build`    | Build e dependências (`pubspec.yaml`, `package.json`, Gradle, Xcode) |
| `ci`       | Pipeline de CI (`.github/workflows`)                                 |
| `chore`    | Outras tarefas de manutenção e configuração                          |
| `revert`   | Reversão de um commit anterior                                       |

Exemplos:

```
feat(reports): cria tela de reporte com foto e localização
fix(network): corrige a mensagem de erro sem conexão
build(deps): atualiza dio para 5.11.2
docs: documenta a tela de diagnóstico
```

Regras:

- A descrição começa com **letra minúscula**, fica no **imperativo** ("cria", "corrige", não "criado" ou "corrigindo") e não termina com ponto.
- O cabeçalho tem no máximo **100 caracteres**.
- O escopo, quando usado, é a feature ou a parte do `core` afetada: `auth`, `reports`, `network`, `config`, `theme`...
- Mudança incompatível: use `!` depois do tipo (`feat(api)!: ...`) e explique no rodapé, em `BREAKING CHANGE:`.
- O antigo prefixo `config:` não é aceito. Use `chore:` ou `build:`.

## Pull Requests

- **Destino:** `develop` para qualquer branch de trabalho. A `main` recebe apenas `release/*`, `hotfix/*` e nada mais.
- **Título:** no mesmo padrão dos commits, por exemplo `feat(reports): cria tela de reporte`. No squash merge, o título do PR vira o commit na `develop`.
- **Descrição:** preencha o template e vincule a issue com `Closes #12`, que fecha a issue automaticamente no merge.
- **Teste no aparelho:** toda mudança de tela ou de configuração nativa é testada no emulador ou num aparelho Android, e também no simulador iOS quando mexe no iOS.
- **Para o merge, são obrigatórios:**
  - **1 aprovação** de outra pessoa da equipe;
  - todas as conversas do review resolvidas;
  - os checks de CI (**Qualidade e testes** e **Build Android**) passando;
  - a branch atualizada em relação ao destino.

### Método de merge

| Origem → destino                   | Método                    | Motivo                                                       |
| ---------------------------------- | ------------------------- | ------------------------------------------------------------ |
| Branch de trabalho → `develop`     | **Squash and merge**      | Um commit por issue, e o histórico da `develop` fica legível |
| `release/*` ou `hotfix/*` → `main` | **Create a merge commit** | Preserva o histórico da versão                               |
| `main` → `develop` (back-merge)    | **Create a merge commit** | Evita conflitos em releases futuras                          |

## Verificações automáticas

| Quando                        | O que roda                                                                                                   | Onde                       |
| ----------------------------- | ------------------------------------------------------------------------------------------------------------ | -------------------------- |
| `git commit`                  | `dart format` nos `.dart` staged e `flutter analyze --fatal-infos` no projeto (quando há `.dart` ou `.yaml`) | `.husky/pre-commit`        |
| `git commit`                  | Validação da mensagem (commitlint)                                                                           | `.husky/commit-msg`        |
| `git push`                    | Validação do nome da branch e bloqueio de push direto em `main` e `develop`                                  | `.husky/pre-push`          |
| PR e push em `develop`/`main` | Formatação, analyzer, testes, cobertura mínima de 80% nas camadas com regras e build do APK de debug         | `.github/workflows/ci.yml` |

O pre-commit roda pelo [lint-staged](.lintstagedrc.mjs), só com o que está staged: um arquivo `.dart` mal formatado sai formatado no commit, e um aviso do analyzer recusa o commit. Os comandos passam pelo FVM, então o `fvm` precisa estar no `PATH` do terminal ou do editor que faz o commit. Os testes não rodam no pre-commit: eles ficam com o CI.

Os hooks são instalados pelo `npm install`, uma vez só. O Node serve só para eles: o app não depende de nenhum pacote do npm.

Numa emergência real, os hooks locais podem ser ignorados com `--no-verify`. A proteção do GitHub continua valendo.

## Configuração do repositório no GitHub

Precisa ser feita **uma única vez**, por alguém com permissão de administrador:

1. **Criar a `develop`** a partir da `main` atual:
   ```bash
   git switch main && git pull
   git switch -c develop
   git push -u origin develop
   ```
2. **Branch padrão:** em _Settings → General → Default branch_, troque para `develop`.
3. **Pull Requests:** em _Settings → General → Pull Requests_:
   - deixe marcados **Allow merge commits** e **Allow squash merging**, e desmarque **Allow rebase merging**;
   - em squash, escolha **Default to pull request title**;
   - marque **Automatically delete head branches**.
4. **Proteção de branches:** em _Settings → Rules → Rulesets → New ruleset → Import a ruleset_, importe os dois arquivos:
   - [.github/rulesets/main.json](.github/rulesets/main.json)
   - [.github/rulesets/develop.json](.github/rulesets/develop.json)

   Eles bloqueiam push direto, force-push e exclusão da branch, e exigem PR com 1 aprovação, conversas resolvidas e os checks de CI passando.

5. **Labels:** crie `Epic`, `Task` e a label da sprint (ex.: `Sprint 4 - 20/10 - 02/11`), como no backend.

Os checks de CI só aparecem para seleção depois que o workflow rodar pela primeira vez. Se a importação reclamar deles, importe o ruleset, abra um PR qualquer para disparar o CI e depois confirme os checks em _Require status checks to pass_.
