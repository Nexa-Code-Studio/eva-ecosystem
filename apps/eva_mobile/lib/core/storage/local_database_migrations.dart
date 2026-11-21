import 'package:sqflite_sqlcipher/sqflite.dart';

/// Database schema migrations for encrypted SQLite (SQLCipher).
class LocalDatabaseMigrations {
  static const int currentVersion = 1;

  static Future<void> onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE memory_items (
        id TEXT PRIMARY KEY,
        local_account_key TEXT NOT NULL,
        category TEXT NOT NULL CHECK (category IN (
          'psychological_complaint','emotional_trigger','coping_strategy',
          'professional_diagnosis','social_support','interaction_preference')),
        fact_text TEXT NOT NULL,
        status TEXT NOT NULL CHECK (status IN
          ('pending_confirmation','active','historical','needs_review')),
        source_type TEXT NOT NULL CHECK (source_type IN
          ('user_reported','clinician_document','assistant_candidate')),
        source_verification TEXT NOT NULL CHECK (source_verification IN
          ('unverified','user_confirmed','verified_document')),
        source_session_id TEXT,
        source_journal_id TEXT,
        consent_record_id TEXT,
        sensitivity TEXT NOT NULL DEFAULT 'health',
        first_seen_at TEXT NOT NULL,
        last_confirmed_at TEXT,
        review_due_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT
      );
    ''');

    await db.execute('''
      CREATE INDEX idx_memory_retrieve 
      ON memory_items(local_account_key, status, category, updated_at);
    ''');

    await db.execute('''
      CREATE TABLE journal_entries (
        id TEXT PRIMARY KEY,
        local_account_key TEXT NOT NULL,
        entry_date_local TEXT NOT NULL,
        title TEXT NOT NULL,
        summary TEXT NOT NULL,
        content TEXT,
        mood_tag TEXT,
        mood_emoji TEXT,
        ai_insight TEXT,
        emotional_reflection TEXT,
        important_events_json TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        UNIQUE(local_account_key, entry_date_local)
      );
    ''');

    await db.execute('''
      CREATE TABLE session_summaries (
        id TEXT PRIMARY KEY,
        local_account_key TEXT NOT NULL,
        client_session_id TEXT NOT NULL,
        summary TEXT NOT NULL,
        journal_id TEXT,
        created_at TEXT NOT NULL,
        UNIQUE(local_account_key, client_session_id)
      );
    ''');

    await db.execute('''
      CREATE TABLE memory_consents (
        id TEXT PRIMARY KEY,
        local_account_key TEXT NOT NULL,
        scope TEXT NOT NULL,
        policy_version TEXT NOT NULL,
        granted_at TEXT,
        revoked_at TEXT,
        consent_snapshot_json TEXT NOT NULL,
        created_at TEXT NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE clinical_share_receipts (
        id TEXT PRIMARY KEY,
        local_account_key TEXT NOT NULL,
        psychologist_id TEXT NOT NULL,
        booking_id TEXT,
        consent_id TEXT NOT NULL,
        payload_categories_json TEXT NOT NULL,
        server_receipt_id TEXT,
        expires_at TEXT,
        sent_at TEXT,
        revoked_at TEXT,
        status TEXT NOT NULL
      );
    ''');
  }

  static Future<void> onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Migration paths for future versions
  }
}
