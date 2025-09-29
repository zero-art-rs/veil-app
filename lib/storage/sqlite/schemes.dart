import 'package:veil/storage/sqlite/consts.dart';

final createContactsTable =
    """
CREATE TABLE $contactsTable (
  actor_id TEXT PRIMARY KEY, 
  name TEXT NOT NULL, 
  public_key BLOB NOT NULL, 
  image BLOB
)""";

final createContactsSpksTable =
    """
CREATE TABLE $contactsSpksTable (
  contact_id TEXT NOT NULL,
  public_key BLOB NOT NULL,
  signature BLOB NOT NULL,
  expires_at TEXT NOT NULL,
  PRIMARY KEY(contact_id, public_key),
  FOREIGN KEY (contact_id) REFERENCES $contactsTable(actor_id) ON DELETE CASCADE
)""";

final createDocumentsTable =
    """
CREATE TABLE $documentsTable (
  id TEXT PRIMARY KEY,
  content BLOB NOT NULL,
  created_at TEXT NOT NULL,
  group_context_parts TEXT NOT NULL,
  sequence_number INTEGER NOT NULL
)""";
