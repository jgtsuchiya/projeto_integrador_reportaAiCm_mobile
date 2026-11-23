import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reportaai_cm/app/app.dart';
import 'package:reportaai_cm/core/network/api_exception.dart';
import 'package:reportaai_cm/features/account/presentation/view_models/edit_profile_view_model.dart';
import 'package:reportaai_cm/features/auth/domain/models/registration_validation.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_controller.dart';
import 'package:reportaai_cm/features/auth/presentation/controllers/auth_state.dart';
import 'package:reportaai_cm/features/profile/domain/models/profile_changes.dart';

import '../../../../support/auth_fakes.dart';
import '../../../../support/fake_profile_repository.dart';

void main() {
  group('EditProfileViewModel', () {
    late AuthFakes fakes;
    late ProviderContainer container;

    setUp(() async {
      fakes = AuthFakes(signedIn: true);
      container = ProviderContainer.test(overrides: fakes.overrides, retry: noAutomaticRetry)
        ..listen(authControllerProvider, (_, _) {})
        ..listen(editProfileViewModelProvider, (_, _) {});
      await pumpEventQueue();
    });

    EditProfileViewModel sut() => container.read(editProfileViewModelProvider.notifier);
    EditProfileState state() => container.read(editProfileViewModelProvider);
    AuthState auth() => container.read(authControllerProvider);

    Future<bool> submit({
      String name = 'Maria da Silva',
      String phone = '(44) 99999-8888',
      String birthDate = '20/05/1990',
    }) => sut().submit(name: name, phone: phone, birthDate: birthDate);

    test('deve salvar só o que mudou e guardar o perfil novo no AuthController', () async {
      final saved = await submit(name: ' Maria Souza ', phone: '(43) 3333-4444');

      expect(saved, isTrue);
      expect(fakes.profile.updateCalls, [
        const ProfileChanges(name: ' Maria Souza ', phone: '4333334444'),
      ]);
      expect(
        auth(),
        AuthAuthenticated(clientProfileWith(name: 'Maria Souza', phone: '4333334444')),
      );
      expect(state(), const EditProfileState());
    });

    test('deve mandar a data de nascimento no formato da API', () async {
      await submit(birthDate: '21/06/1991');

      expect(fakes.profile.updateCalls.single, const ProfileChanges(birthDate: '1991-06-21'));
    });

    test('não deve chamar a API sem mudança', () async {
      final saved = await submit();

      expect(saved, isFalse);
      expect(fakes.profile.updateCalls, isEmpty);
    });

    test('deve recusar os campos inválidos antes de enviar (RM11)', () async {
      final saved = await submit(name: '', phone: '(44) 9999', birthDate: '20/05');

      expect(saved, isFalse);
      expect(state().fieldErrors, {
        ProfileField.name: RegistrationMessages.nameMissing,
        ProfileField.phone: RegistrationMessages.phoneInvalid,
        ProfileField.birthDate: RegistrationMessages.birthDateInvalid,
      });
      expect(fakes.profile.updateCalls, isEmpty);
    });

    test('deve mostrar o 400 de cada campo, embaixo dele', () async {
      fakes.profile.updateError = const ValidationException(
        fieldErrors: [
          FieldError(field: 'phone', message: 'Telefone inválido.'),
          FieldError(field: 'cpf', message: 'Campo que o app não edita.'),
        ],
      );

      final saved = await submit(phone: '(44) 98888-7777');

      expect(saved, isFalse);
      expect(state().fieldErrors, {ProfileField.phone: 'Telefone inválido.'});
      expect(auth(), AuthAuthenticated(clientProfile));
    });

    test('deve mostrar a mensagem geral do 400 sem um campo conhecido', () async {
      fakes.profile.updateError = const ValidationException(
        message: 'Informe pelo menos um campo para alterar.',
      );

      await submit(name: 'Maria Souza');

      expect(state(), const EditProfileState(message: 'Informe pelo menos um campo para alterar.'));
    });

    test('deve mostrar o erro sem conexão e manter o perfil', () async {
      fakes.profile.updateError = const NetworkException();

      final saved = await submit(name: 'Maria Souza');

      expect(saved, isFalse);
      expect(state().message, NetworkException.defaultMessage);
      expect(auth(), AuthAuthenticated(clientProfile));
    });

    test('deve ignorar o envio durante outro', () async {
      final pending = fakes.profile.updatePending = Completer<void>();

      final first = submit(name: 'Maria Souza');
      await pumpEventQueue();
      expect(state().isSubmitting, isTrue);
      final second = await submit(name: 'Maria Souza');
      pending.complete();
      await first;

      expect(second, isFalse);
      expect(fakes.profile.updateCalls, hasLength(1));
    });

    test('não deve salvar sem o Client dentro', () async {
      await container.read(authControllerProvider.notifier).signOut();

      expect(await submit(name: 'Maria Souza'), isFalse);
      expect(fakes.profile.updateCalls, isEmpty);
    });

    test('deve tirar o erro do campo editado e manter o dos outros', () async {
      await submit(name: '', phone: '');

      sut().fieldChanged(ProfileField.name);

      expect(state().fieldErrors, {ProfileField.phone: RegistrationMessages.phoneMissing});
      final before = state();
      sut().fieldChanged(ProfileField.birthDate);
      expect(state(), same(before));
    });

    test('deve comparar o estado pelo valor', () {
      const a = EditProfileState(fieldErrors: {ProfileField.name: 'erro'}, message: 'aviso');
      const b = EditProfileState(fieldErrors: {ProfileField.name: 'erro'}, message: 'aviso');

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a.toString(), contains('aviso'));
    });
  });
}
