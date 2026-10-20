String inquiryText = 'I want to change the address my invoices are sent to';
aiplatform.ModelsAPI.createGenerations_Request request =
    new aiplatform.ModelsAPI.createGenerations_Request();
request.modelName = 'sfdc_ai__DefaultOpenAIGPT4OmniMini';

aiplatform.ModelsAPI_GenerationRequest body =
    new aiplatform.ModelsAPI_GenerationRequest();
body.prompt = 'Classify the following inquiry as "Billing", "Technical", or "Other", and return only that word.\n'
            + inquiryText;
request.body = body;

try {
    aiplatform.ModelsAPI api = new aiplatform.ModelsAPI();
    aiplatform.ModelsAPI.createGenerations_Response res = api.createGenerations(request);
    String category = res.Code200.generation.generatedText.trim();
} catch (aiplatform.ModelsAPI.createGenerations_ResponseException e) {
    System.debug('HTTP ' + e.responseCode + ' : ' + e);
}