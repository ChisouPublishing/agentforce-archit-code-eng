// Resolve the given keys with the standard Apex Label API. No SOQL is needed.
private static Map<String, String> resolveAll(Set<String> keys) {
    Map<String, String> result = new Map<String, String>();
    if (keys == null) { return result; }
    for (String key : keys) {
        if (String.isBlank(key)) { continue; }
        try {
            result.put(key, System.Label.get('', key, UserInfo.getLanguage()));
        } catch (Exception e) {
            // Leave undefined keys out of the result. Never show key names to users.
        }
    }
    return result;
}