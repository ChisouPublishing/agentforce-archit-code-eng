public with sharing class LocalizedMessageProvider {

    public class Request {
        @InvocableVariable(required=true label='Label Developer Name')
        public String labelKey;

        @InvocableVariable(label='Language Code (defaults to the running user\'s language)')
        public String language;
    }
    public class Result {
        @InvocableVariable public String message;
        @InvocableVariable public Boolean found;
    }

    @InvocableMethod(label='Get Translated Message'
                     description='Returns a custom label in the specified language or the running user\'s language')
    public static List<Result> getMessage(List<Request> requests) {
        List<Result> results = new List<Result>();

        if (requests == null) { return results; }
        for (Request req : requests) {
            Result r = new Result();
            r.found = false;
            r.message = '';

            if (req == null || String.isBlank(req.labelKey)) { results.add(r); continue; }

            // Without a language, use the running user's language (e.g. 'en_US', 'es')
            String lang = String.isNotBlank(req.language)
                        ? req.language : UserInfo.getLanguage();
            try {
                if (System.Label.translationExists('', req.labelKey, lang)) {
                    r.message = System.Label.get('', req.labelKey, lang);
                } else {
                    // Without a translation, get it in the running user's default language
                    r.message = System.Label.get('', req.labelKey);
                }
                r.found = String.isNotBlank(r.message);
            } catch (Exception e) {
                // Warning: a key that does not exist can throw an exception.
                //    Returning the key name here would expose the developer name to customers
                r.message = '';
                r.found = false;
            }
            results.add(r);
        }
        return results;
    }
}