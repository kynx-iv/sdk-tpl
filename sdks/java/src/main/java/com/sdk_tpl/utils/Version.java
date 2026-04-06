package com.sdk_tpl.utils;

/**
 * Version information for the {{SDK_NAME}} SDK.
 */
public final class Version {

    /**
     * The current SDK version.
     */
    public static final String SDK_VERSION = "{{SDK_VERSION}}";

    /**
     * The SDK name.
     */
    public static final String SDK_NAME = "{{SDK_NAME}}";

    /**
     * The SDK user agent string.
     */
    public static final String USER_AGENT = "{{SDK_SLUG}}-sdk-java/" + SDK_VERSION;

    private Version() {
        // Utility class
    }
}
