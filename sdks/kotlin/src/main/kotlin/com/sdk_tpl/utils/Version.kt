package com.sdk_tpl.utils

/**
 * Version information for the {{SDK_NAME}} SDK.
 */
object Version {

    /** The current SDK version. */
    const val SDK_VERSION: String = "{{SDK_VERSION}}"

    /** The SDK identifier used in User-Agent headers. */
    const val SDK_IDENTIFIER: String = "{{SDK_SLUG}}-kotlin"

    /** The full User-Agent string. */
    val USER_AGENT: String = "$SDK_IDENTIFIER/$SDK_VERSION"
}
