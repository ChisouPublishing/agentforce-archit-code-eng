String inquiryText = 'I want to check my Agentforce settings';
aiplatform.ModelsAPI.createChatGenerations_Request request =
    new aiplatform.ModelsAPI.createChatGenerations_Request();
request.modelName = 'sfdc_ai__DefaultOpenAIGPT4OmniMini';

aiplatform.ModelsAPI_ChatGenerationsRequest body =
    new aiplatform.ModelsAPI_ChatGenerationsRequest();

List<aiplatform.ModelsAPI_ChatMessageRequest> messages =
    new List<aiplatform.ModelsAPI_ChatMessageRequest>();

aiplatform.ModelsAPI_ChatMessageRequest sys = new aiplatform.ModelsAPI_ChatMessageRequest();
sys.role = 'system';
sys.content = 'You extract only product names from the given text. If none are found, return an empty string.';
messages.add(sys);

aiplatform.ModelsAPI_ChatMessageRequest usr = new aiplatform.ModelsAPI_ChatMessageRequest();
usr.role = 'user';
usr.content = inquiryText;
messages.add(usr);

body.messages = messages;
request.body = body;

aiplatform.ModelsAPI api = new aiplatform.ModelsAPI();
aiplatform.ModelsAPI.createChatGenerations_Response res = api.createChatGenerations(request);
// res.Code200.generationDetails.generations