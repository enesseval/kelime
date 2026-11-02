package com.enesseval.kilitkelime.core.model

import kotlinx.serialization.json.Json as KJson

/** The JSON configuration shared by content import, stored grids and sync payloads. */
val Json: KJson = KJson {
    ignoreUnknownKeys = true
    explicitNulls = false
    encodeDefaults = true
}
