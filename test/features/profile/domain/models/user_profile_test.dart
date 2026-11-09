import 'package:flutter_test/flutter_test.dart';
import 'package:reportaai_cm/features/profile/domain/models/role.dart';
import 'package:reportaai_cm/features/profile/domain/models/user_profile.dart';

import '../../../../support/fake_profile_repository.dart';

void main() {
  group('UserProfile', () {
    UserProfile copyOf(UserProfile profile, {Role? role, String? cpf, DateTime? birthDate}) =>
        UserProfile(
          id: profile.id,
          role: role ?? profile.role,
          name: profile.name,
          email: profile.email,
          status: profile.status,
          mfaEnabled: profile.mfaEnabled,
          createdAt: profile.createdAt,
          updatedAt: profile.updatedAt,
          emailVerifiedAt: profile.emailVerifiedAt,
          lastLoginAt: profile.lastLoginAt,
          cpf: cpf ?? profile.cpf,
          phone: profile.phone,
          birthDate: birthDate ?? profile.birthDate,
        );

    test('deve comparar pelo valor', () {
      expect(copyOf(clientProfile), clientProfile);
      expect(copyOf(clientProfile).hashCode, clientProfile.hashCode);
      expect(copyOf(clientProfile, role: Role.admin), isNot(clientProfile));
      expect(copyOf(clientProfile, cpf: '11144477735'), isNot(clientProfile));
      expect(copyOf(clientProfile, birthDate: DateTime(1990, 5, 21)), isNot(clientProfile));
    });

    test('não deve mostrar o CPF no toString (RM09)', () {
      final sut = clientProfile.toString();

      expect(sut, isNot(contains(clientProfile.cpf)));
      expect(sut, contains('cpf: ***'));
      expect(sut, contains('name: Maria da Silva'));
    });

    test('deve mostrar o CPF ausente como null no toString', () {
      expect(adminProfile.toString(), contains('cpf: null'));
    });
  });
}
