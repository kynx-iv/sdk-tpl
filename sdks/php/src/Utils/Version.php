<?php

declare(strict_types=1);

namespace SdkTpl\Utils;

/**
 * Version information for the {{SDK_NAME}} SDK.
 */
class Version
{
    /** The current SDK version. */
    public const SDK_VERSION = '{{SDK_VERSION}}';

    /** The SDK identifier used in User-Agent headers. */
    public const SDK_IDENTIFIER = '{{SDK_SLUG}}-php';

    /** Returns the full User-Agent string. */
    public static function userAgent(): string
    {
        return self::SDK_IDENTIFIER . '/' . self::SDK_VERSION;
    }
}
