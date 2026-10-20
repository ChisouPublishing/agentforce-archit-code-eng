// Input for verification. In practice, the caller passes the Case ID.
Id caseId = null;
// Input parameters (must match the input names defined in the template)
Map<String, String> record = new Map<String, String>{ 'id' => caseId };
ConnectApi.WrappedValue recordValue = new ConnectApi.WrappedValue();
recordValue.value = record;

Map<String, ConnectApi.WrappedValue> inputParams =
    new Map<String, ConnectApi.WrappedValue>();
inputParams.put('Input:Case', recordValue);

ConnectApi.EinsteinPromptTemplateGenerationsInput input =
    new ConnectApi.EinsteinPromptTemplateGenerationsInput();
input.additionalConfig = new ConnectApi.EinsteinLlmAdditionalConfigInput();
input.additionalConfig.applicationName = 'PromptBuilderPreview';
input.isPreview   = false;
input.inputParams = inputParams;

ConnectApi.EinsteinPromptTemplateGenerationsRepresentation out =
    ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(
        'Summarize_Case_For_Handoff',   // API name of the template
        input
    );

String text = out.generations[0].text;