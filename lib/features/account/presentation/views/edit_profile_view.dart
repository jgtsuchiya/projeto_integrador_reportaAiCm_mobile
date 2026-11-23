import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:reportaai_cm/core/utils/cpf_formatters.dart';
import 'package:reportaai_cm/core/utils/date_formatters.dart';
import 'package:reportaai_cm/core/utils/phone_formatters.dart';
import 'package:reportaai_cm/core/widgets/app_text_field.dart';
import 'package:reportaai_cm/core/widgets/primary_button.dart';
import 'package:reportaai_cm/core/widgets/scrollable_center.dart';
import 'package:reportaai_cm/features/account/presentation/view_models/edit_profile_view_model.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_controller.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_state.dart';
import 'package:reportaai_cm/features/profile/domain/models/profile_changes.dart';
import 'package:reportaai_cm/features/profile/domain/models/user_profile.dart';

/// "Editar dados" (`/conta/dados`): o nome, o telefone e a data de nascimento, com as regras e as
/// máscaras do cadastro. O e-mail e o CPF (mascarado, RM09) aparecem, sem edição.
///
/// Só os campos que mudaram vão para a API, e sem mudança o "Salvar" fica desativado. Ao sair com
/// alterações não salvas, a tela pergunta se quer descartá-las.
class EditProfileView extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<EditProfileView> createState() => _EditProfileViewState();
}

class _EditProfileViewState extends ConsumerState<EditProfileView> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _birthDate;

  @override
  void initState() {
    super.initState();
    final profile = _profile;
    _name = TextEditingController(text: profile?.name);
    _phone = TextEditingController(
      text: switch (profile?.phone) {
        final phone? => formatPhone(phone),
        null => '',
      },
    );
    _birthDate = TextEditingController(
      text: switch (profile?.birthDate) {
        // Uma data sem hora: sem o `toLocal()`, para não mudar o dia.
        final date? => formatDate(date),
        null => '',
      },
    );
  }

  @override
  void dispose() {
    for (final controller in [_name, _phone, _birthDate]) {
      controller.dispose();
    }
    super.dispose();
  }

  UserProfile? get _profile => switch (ref.read(authControllerProvider)) {
    AuthAuthenticated(:final profile) => profile,
    _ => null,
  };

  ProfileChanges _changesFrom(UserProfile profile) => profileChangesOfFields(
    profile,
    name: _name.text,
    phone: _phone.text,
    birthDate: _birthDate.text,
  );

  Future<void> _submit() async {
    final saved = await ref
        .read(editProfileViewModelProvider.notifier)
        .submit(name: _name.text, phone: _phone.text, birthDate: _birthDate.text);
    if (!saved || !mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text(EditProfileViewModel.savedMessage)));
    context.pop();
  }

  /// O "voltar" com alterações não salvas: pergunta antes de descartá-las.
  Future<void> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Descartar as alterações?'),
        content: const Text('Os dados que você mudou não foram salvos.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Continuar editando'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) context.pop();
  }

  void _fieldChanged(ProfileField field) =>
      ref.read(editProfileViewModelProvider.notifier).fieldChanged(field);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final editing = ref.watch(editProfileViewModelProvider);
    final message = editing.message;
    // Depois da exclusão ou do fim da sessão, a tela ainda aparece durante a troca para o login.
    final profile = switch (ref.watch(authControllerProvider)) {
      AuthAuthenticated(:final profile) => profile,
      _ => null,
    };

    return ListenableBuilder(
      listenable: Listenable.merge([_name, _phone, _birthDate]),
      builder: (context, child) {
        final hasChanges = profile != null && !_changesFrom(profile).isEmpty;

        return PopScope(
          canPop: !hasChanges,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) unawaited(_confirmDiscard());
          },
          child: child!,
        );
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Editar dados')),
        body: SafeArea(
          child: profile == null
              ? const SizedBox.shrink()
              : ScrollableCenter(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppTextField(
                        label: 'Nome completo',
                        controller: _name,
                        errorText: editing.errorFor(ProfileField.name),
                        textInputAction: TextInputAction.next,
                        textCapitalization: TextCapitalization.words,
                        autofillHints: const [AutofillHints.name],
                        onChanged: (_) => _fieldChanged(ProfileField.name),
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        label: 'Telefone',
                        controller: _phone,
                        errorText: editing.errorFor(ProfileField.phone),
                        hintText: '(00) 00000-0000',
                        helperText: 'Com o DDD',
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.telephoneNumber],
                        inputFormatters: const [PhoneInputFormatter()],
                        onChanged: (_) => _fieldChanged(ProfileField.phone),
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        label: 'Data de nascimento',
                        controller: _birthDate,
                        errorText: editing.errorFor(ProfileField.birthDate),
                        hintText: 'dd/mm/aaaa',
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        autocorrect: false,
                        enableSuggestions: false,
                        inputFormatters: const [DateInputFormatter()],
                        onChanged: (_) => _fieldChanged(ProfileField.birthDate),
                        onFieldSubmitted: (_) => unawaited(_submit()),
                        scrollPadding: const EdgeInsets.fromLTRB(20, 20, 20, 240),
                      ),
                      const SizedBox(height: 24),
                      _ReadOnlyField(label: 'E-mail', value: profile.email),
                      if (profile.cpf case final cpf?)
                        _ReadOnlyField(label: 'CPF', value: maskCpf(cpf)),
                      Text(
                        'O e-mail e o CPF não podem ser alterados.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (message != null) ...[
                        const SizedBox(height: 16),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            message,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      ListenableBuilder(
                        listenable: Listenable.merge([_name, _phone, _birthDate]),
                        builder: (context, _) => PrimaryButton(
                          label: 'Salvar',
                          isLoading: editing.isSubmitting,
                          // Sem mudança, nada a salvar.
                          onPressed: _changesFrom(profile).isEmpty
                              ? null
                              : () => unawaited(_submit()),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

/// Um dado que aparece sem edição: o rótulo em cima e o valor embaixo.
class _ReadOnlyField extends StatelessWidget {
  const new({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      // O leitor de tela lê o rótulo e o valor juntos: "CPF, ***.982.247-**".
      child: MergeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Text(value, style: theme.textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}
