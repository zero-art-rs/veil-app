import 'external_account.dart';

class DocumentMember {
  final ExternalAccount account;
  final int role;
  final String roleName;
  final int status;

  DocumentMember({
    required this.account,
    required this.role,
    required this.roleName,
    required this.status,
  });
}
