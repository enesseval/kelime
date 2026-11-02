package com.enesseval.kilitkelime.core.content

import com.enesseval.kilitkelime.core.db.SqlDb

/** Forces an import regardless of version (tests, developer tools). */
object ContentImporterAccess {
    fun apply(text: String, db: SqlDb) = ContentImporter.apply(ContentImporter.decode(text), db) {}
}
