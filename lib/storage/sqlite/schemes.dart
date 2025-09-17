import 'package:zk_notion_app/storage/sqlite/consts.dart';

final createAccountTable =
    """
CREATE TABLE $accountsTable (
  actor_id TEXT PRIMARY KEY, 
  name TEXT NOT NULL, 
  public_key BLOB NOT NULL, 
  image BLOB,
  kind TEXT NOT NULL
)""";

final createContactsSpksTable =
    """
CREATE TABLE $contactsSpksTable (
  contact_id TEXT NOT NULL,
  public_key BLOB NOT NULL,
  signature BLOB NOT NULL,
  expires_at TEXT NOT NULL,
  PRIMARY KEY(contact_id, public_key),
  FOREIGN KEY (contact_id) REFERENCES $accountsTable(actor_id) ON DELETE CASCADE
)""";

final createDocumentsTable =
    """
CREATE TABLE $documentsTable (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  content BLOB NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
)""";

final createDocumentMembersTable =
    """
CREATE TABLE $documentMembersTable (
  actor_id TEXT NOT NULL,
  document_id TEXT NOT NULL,
  role INTEGER NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  PRIMARY KEY (actor_id, document_id),
  FOREIGN KEY (document_id) REFERENCES $documentsTable(id) ON DELETE CASCADE
)""";

final createEpochsTable =
    """
CREATE TABLE $epochsTable (
  group_id TEXT NOT NULL,
  epoch INTEGER NOT NULL,
  stage_key BLOB NOT NULL,
  leaf_secret BLOB NOT NULL,
  art BLOB NOT NULL,

  PRIMARY KEY (group_id, epoch),
  FOREIGN KEY (group_id) REFERENCES $groupsTable(id) ON DELETE CASCADE
)
""";

final createGroupsTable =
    """
CREATE TABLE $groupsTable (
  id TEXT PRIMARY KEY,
  identity_id TEXT NOT NULL,
  metadata BLOB NOT NULL
)
""";

final accountCleanupTrigger =
    """CREATE TRIGGER delete_account_if_not_contact
AFTER DELETE ON $documentMembersTable
FOR EACH ROW
BEGIN
  DELETE FROM $accountsTable
  WHERE actor_id = OLD.actor_id
    AND kind = '${AccountKind.familiar.name}'
    AND NOT EXISTS (
      SELECT 1
      FROM $documentMembersTable
      WHERE actor_id = OLD.actor_id
    );
END;
""";

final removeSpksOnFamiliarTrigger =
    """
CREATE TRIGGER remove_spks_on_familiar
AFTER UPDATE OF kind ON $accountsTable
FOR EACH ROW
WHEN NEW.kind = 'familiar'
BEGIN
  DELETE FROM $contactsSpksTable WHERE contact_id = NEW.actor_id;
END;
""";
