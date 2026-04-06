"""SDK version information."""

SDK_VERSION: str = "{{SDK_VERSION}}"


def get_version() -> str:
    """Return the current SDK version string.

    Returns:
        The SDK version.
    """
    return SDK_VERSION
