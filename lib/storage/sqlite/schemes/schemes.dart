import 'package:zk_notion_app/storage/sqlite/models/consts.dart';

final createAccountTable =
    """
CREATE TABLE $accountsTable (
  actor_id TEXT PRIMARY KEY, 
  name TEXT NOT NULL, 
  public_key TEXT NOT NULL, 
  image BLOB,
  kind TEXT NOT NULL
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
