// Builds the citation (source) attached to an action's response. GenAiCitationOutput attaches the source chosen
// by the action directly, without going through the reasoning engine's citation service
// (official docs: "Cite Agent Responses with Apex").
// The source is a record page employees can open (never cite a URL the user cannot see).
global with sharing class AFD_ReturnCitations {
    global static AiCopilot.GenAiCitationOutput of(Id recordId, String objectApiName, String label) {
        if (recordId == null) { return null; }
        String link = '/lightning/r/' + objectApiName + '/' + recordId + '/view';
        AiCopilot.GenAiCitedReferenceInfo info =
            new AiCopilot.GenAiCitedReferenceInfo(link, recordId, objectApiName, label);
        AiCopilot.GenAiCitedReference ref =
            new AiCopilot.GenAiCitedReference(new List<AiCopilot.GenAiCitedReferenceInfo>{ info });
        return new AiCopilot.GenAiCitationOutput(new List<AiCopilot.GenAiCitedReference>{ ref });
    }
}
