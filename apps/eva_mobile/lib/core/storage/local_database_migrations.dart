import 'package:sqflite_sqlcipher/sqflite.dart';

/// Database schema migrations for encrypted SQLite (SQLCipher).
class LocalDatabaseMigrations {
  static const int currentVersion = 3;

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
        emotions_breakdown_json TEXT,
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
        emotions_breakdown_json TEXT,
        synthesis_status TEXT NOT NULL DEFAULT 'completed',
        created_at TEXT NOT NULL,
        UNIQUE(local_account_key, client_session_id)
      );
    ''');

    await db.execute('''
      CREATE TABLE conversation_turns (
        id TEXT PRIMARY KEY,
        local_account_key TEXT NOT NULL,
        session_id TEXT NOT NULL,
        turn_id INTEGER NOT NULL,
        role TEXT NOT NULL CHECK (role IN ('user', 'assistant')),
        transcript TEXT NOT NULL,
        created_at TEXT NOT NULL,
        UNIQUE(local_account_key, session_id, turn_id, role)
      );
    ''');

    await db.execute('''
      CREATE INDEX idx_conversation_turns_session 
      ON conversation_turns(local_account_key, session_id, turn_id);
    ''');

    await db.execute('''
      CREATE TABLE local_dass_assessments (
        id TEXT PRIMARY KEY,
        local_account_key TEXT NOT NULL,
        assessment_date TEXT NOT NULL,
        stress_score INTEGER NOT NULL DEFAULT 0,
        anxiety_score INTEGER NOT NULL DEFAULT 0,
        depression_score INTEGER NOT NULL DEFAULT 0,
        stress_category TEXT NOT NULL DEFAULT 'Normal',
        anxiety_category TEXT NOT NULL DEFAULT 'Normal',
        depression_category TEXT NOT NULL DEFAULT 'Normal',
        items_json TEXT NOT NULL,
        source_session_id TEXT,
        is_user_verified INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        UNIQUE(local_account_key, assessment_date)
      );
    ''');

    await db.execute('''
      CREATE INDEX idx_dass_date 
      ON local_dass_assessments(local_account_key, assessment_date);
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
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS conversation_turns (
          id TEXT PRIMARY KEY,
          local_account_key TEXT NOT NULL,
          session_id TEXT NOT NULL,
          turn_id INTEGER NOT NULL,
          role TEXT NOT NULL CHECK (role IN ('user', 'assistant')),
          transcript TEXT NOT NULL,
          created_at TEXT NOT NULL,
          UNIQUE(local_account_key, session_id, turn_id, role)
        );
      ''');
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_conversation_turns_session 
        ON conversation_turns(local_account_key, session_id, turn_id);
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS local_dass_assessments (
          id TEXT PRIMARY KEY,
          local_account_key TEXT NOT NULL,
          assessment_date TEXT NOT NULL,
          stress_score INTEGER NOT NULL DEFAULT 0,
          anxiety_score INTEGER NOT NULL DEFAULT 0,
          depression_score INTEGER NOT NULL DEFAULT 0,
          stress_category TEXT NOT NULL DEFAULT 'Normal',
          anxiety_category TEXT NOT NULL DEFAULT 'Normal',
          depression_category TEXT NOT NULL DEFAULT 'Normal',
          items_json TEXT NOT NULL,
          source_session_id TEXT,
          is_user_verified INTEGER NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          UNIQUE(local_account_key, assessment_date)
        );
      ''');
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_dass_date 
        ON local_dass_assessments(local_account_key, assessment_date);
      ''');
      try {
        await db.execute("ALTER TABLE session_summaries ADD COLUMN synthesis_status TEXT NOT NULL DEFAULT 'completed';");
      } catch (_) {}
    }
    if (oldVersion < 3) {
      try {
        await db.execute("ALTER TABLE journal_entries ADD COLUMN emotions_breakdown_json TEXT;");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE session_summaries ADD COLUMN emotions_breakdown_json TEXT;");
      } catch (_) {}
    }
  }
}
