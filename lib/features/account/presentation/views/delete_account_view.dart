import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:reportaai_cm/core/widgets/scrollable_center.dart';
import 'package:reportaai_cm/features/account/presentation/view_models/delete_account_view_model.dart';
import 'package:reportaai_cm/features/account/presentation/widgets/password_field.dart';

/// "Excluir conta" (`/conta/excluir`): o que acontece com a conta, a senha atual e a confirmação
/// explícita (RN11, RN15 e RM17). O "Excluir minha conta", na cor de erro, só fica ativo com as
/// duas. Depois da exclusão, o app apaga a sessão do aparelho e volta ao login com o aviso.
///
/// A exclusão dentro do app é exigência da Google Play para os apps que permitem criar conta.
class DeleteAccountView extends ConsumerStatefulWidget {
  const new({super.key});

  static const consequences = [
    'Os seus dados pessoais (CPF, telefone e data de nascimento) são apagados.',
    'O seu nome vira "Usuário excluído".',
    'A conta sai de todos os aparelhos.',
    'O e-mail e o CPF ficam livres para um novo cadastro.',
    'Os reportes que você abriu continuam com a prefeitura, sem o seu nome.',
  ];

  @override
  ConsumerState<DeleteAccountView> createState() => _DeleteAccountViewState();
}

class _DeleteAccountViewState extends ConsumerState<DeleteAccountView> {
  final _password = TextEditingController();
  bool _isConfirmed = false;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final isPasswordCorrect = await ref
        .read(deleteAccountViewModelProvider.notifier)
        .submit(_password.text);
    if (!isPasswordCorrect && mounted) _password.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final deletion = ref.watch(deleteAccountViewModelProvider);
    final message = deletion.message;

    return Scaffold(
      appBar: AppBar(title: const Text('Excluir conta')),
      body: SafeArea(
        child: ScrollableCenter(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  'A exclusão não pode ser desfeita',
                  style: theme.textTheme.titleLarge?.copyWith(color: colors.error),
                ),
              ),
              const SizedBox(height: 16),
              Text('Ao excluir a conta:', style: theme.textTheme.bodyLarge),
              const SizedBox(height: 8),
              for (final item in DeleteAccountView.consequences)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.circle, size: 8, color: colors.onSurfaceVariant),
                      const SizedBox(width: 12),
                      Expanded(child: Text(item, style: theme.textTheme.bodyMedium)),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              AutofillGroup(
                onDisposeAction: AutofillContextAction.cancel,
                child: PasswordField(
                  label: 'Senha atual',
                  controller: _password,
                  errorText: deletion.passwordError,
                  autofillHints: const [AutofillHints.password],
                  textInputAction: TextInputAction.done,
                  onChanged: (_) {
                    // O botão depende da senha preenchida.
                    setState(() {});
                    ref.read(deleteAccountViewModelProvider.notifier).passwordChanged();
                  },
                ),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                value: _isConfirmed,
                onChanged: deletion.isSubmitting
                    ? null
                    : (value) => setState(() => _isConfirmed = value ?? false),
                title: const Text('Entendo que a exclusão não pode ser desfeita'),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              if (message != null) ...[
                const SizedBox(height: 16),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    message,
                    style: theme.textTheme.bodyLarge?.copyWith(color: colors.error),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              _DeleteButton(
                isLoading: deletion.isSubmitting,
                onPressed: _isConfirmed && _password.text.isNotEmpty
                    ? () => unawaited(_submit())
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// O "Excluir minha conta", na cor de erro. Carregando, mostra o indicador e ignora o toque.
class _DeleteButton extends StatelessWidget {
  const new({required this.isLoading, required this.onPressed});

  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final style = FilledButton.styleFrom(
      backgroundColor: colors.error,
      foregroundColor: colors.onError,
      // Carregando, o botão fica sem ação, mas com a cor de ativo.
      disabledBackgroundColor: isLoading ? colors.error : null,
      disabledForegroundColor: isLoading ? colors.onError : null,
    );

    return FilledButton(
      onPressed: isLoading ? null : onPressed,
      style: style,
      child: isLoading
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colors.onError,
                    semanticsLabel: 'Excluindo',
                  ),
                ),
                const SizedBox(width: 12),
                const Flexible(child: Text('Excluir minha conta')),
              ],
            )
          : const Text('Excluir minha conta'),
    );
  }
}
