// In a regular org (not a package), pass an empty string as the namespace
String msg = System.Label.get('', 'RefundPolicyNotice');

// To get a specific language (language is an ISO language code)
String es = System.Label.get('', 'RefundPolicyNotice', 'es');

// You can check first whether a translation exists for that language
Boolean exists = System.Label.translationExists('', 'RefundPolicyNotice', 'es');