aiplatform.ModelsAPI.createEmbeddings_Request request =
    new aiplatform.ModelsAPI.createEmbeddings_Request();
request.modelName = 'sfdc_ai__DefaultOpenAITextEmbeddingAda_002';

aiplatform.ModelsAPI_EmbeddingRequest body = new aiplatform.ModelsAPI_EmbeddingRequest();
body.input = new List<String>{ 'The screen goes blank after I log in' };
request.body = body;

aiplatform.ModelsAPI api = new aiplatform.ModelsAPI();
aiplatform.ModelsAPI.createEmbeddings_Response res = api.createEmbeddings(request);
// res.Code200.embeddings