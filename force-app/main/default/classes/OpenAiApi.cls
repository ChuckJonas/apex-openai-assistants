public class OpenAiApi {
  private static HttpResponse baseRequest(String endpoint, String method, Object body) {
    HttpRequest req = new HttpRequest();
    req.setEndpoint('callout:OpenAI' + endpoint);
    req.setMethod(method);
    req.setHeader('Content-Type', 'application/json');
    req.setHeader('OpenAI-Beta', 'assistants=v1');
    if (body != null) {
      req.setBody(JSON.serialize(body, true));
    }

    Http http = new Http();
    HttpResponse res = http.send(req);

    if (res.getStatusCode() >= 400) {
      throw new CalloutException(
        'OpenAI API returned status code ' + res.getStatusCode() + ' with message: ' + res.getBody()
      );
    }
    return res;
  }

  // https://platform.openai.com/docs/api-reference/threads/createThread
  // returns threadId
  public static String createThread(List<RequestMessage> messages, Map<String, Object> metadata) {
    String endpoint = '/threads';
    Map<String, Object> body = new Map<String, Object>{ 'messages' => messages, 'metadata' => metadata };

    HttpResponse res = baseRequest(endpoint, 'POST', body);
    Map<String, Object> resBody = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
    return (String) resBody.get('id');
  }

  // https://platform.openai.com/docs/api-reference/messages/createMessage
  public static ThreadMessage createMessage(String threadId, RequestMessage message) {
    String endpoint = '/threads/' + threadId + '/messages';

    HttpResponse res = baseRequest(endpoint, 'POST', message);
    return (ThreadMessage) JSON.deserialize(res.getBody(), ThreadMessage.class);
  }

  // https://platform.openai.com/docs/api-reference/messages/listMessages
  public static ThreadMessageList listMessages(String threadId) {
    String endpoint = '/threads/' + threadId + '/messages';
    HttpResponse res = baseRequest(endpoint, 'GET', null);
    return (ThreadMessageList) JSON.deserialize(res.getBody(), ThreadMessageList.class);
  }

  // https://platform.openai.com/docs/api-reference/runs/createRun
  public static Run createRun(String threadId, String assistantId) {
    String endpoint = '/threads/' + threadId + '/runs';
    Map<String, Object> body = new Map<String, Object>{ 'assistant_id' => assistantId };

    HttpResponse res = baseRequest(endpoint, 'POST', body);
    return (Run) JSON.deserialize(res.getBody(), Run.class);
  }

  // https://platform.openai.com/docs/api-reference/runs/getRun
  public static Run getRun(String threadId, String runId) {
    String endpoint = '/threads/' + threadId + '/runs/' + runId;
    HttpResponse res = baseRequest(endpoint, 'GET', null);
    return (Run) JSON.deserialize(res.getBody(), Run.class);
  }

  // https://platform.openai.com/docs/api-reference/runs/submitToolOutputs
  public static HttpResponse submitToolOutputs(String threadId, String runId, List<ToolOutput> outputs) {
    String endpoint = '/threads/' + threadId + '/runs/' + runId + '/submit_tool_outputs';

    Map<String, Object> body = new Map<String, Object>{ 'tool_outputs' => outputs };

    return baseRequest(endpoint, 'POST', body);
  }

  public class RequestMessage {
    public RequestMessage(String role, String content) {
      this.role = role;
      this.content = content;
    }
    public String role;
    public String content;
    public String file_ids;
    public Map<String, Object> metadata;
  }

  public class Run {
    public string thread_id;
    public String status;
    public String id;
    public RequiredAction required_action;
  }

  public class RequiredAction {
    public SubmitToolOutputs submit_tool_outputs;
  }

  public class SubmitToolOutputs {
    public List<ToolCall> tool_calls;
  }

  public class ToolCall {
    public String id;
    public ToolFn function;
  }

  public class ToolFn {
    public String name;
    public String arguments;
  }

  public class ToolOutput {
    public ToolOutput(String tool_call_id) {
      this.tool_call_id = tool_call_id;
    }
    public String tool_call_id;
    public String output;
  }

  public class ThreadMessageList {
    // public String object;
    public List<ThreadMessage> data;
    public String first_id;
    public String last_id;
    public Boolean has_more;
  }

  public class ThreadMessage {
    public String id;
    // public String object;
    public Integer created_at;
    public String thread_id;
    public String role;
    public List<MessageContent> content;
    public List<String> file_ids;
    public String assistant_id;
    public String run_id;
    public Map<String, Object> metadata;
  }

  public class MessageContent {
    public String type;
    public MessageText text;
  }

  public class MessageText {
    public String value;
    public List<Object> annotations;
  }
}
