// see ../demoAssistant.json for assistant specification
public class DemoAssistant implements IAssistant {
  public String getAssistantId() {
    // update this to your assistant id
    return 'asst_pDy0C9M02xRr1eobiphuFuEy';
  }

  public Map<string, IAssistantTool> getToolBox() {
    return new Map<String, IAssistantTool>{
      'run_soql' => new RunSOQLTool(),
      'full_text_search' => new FullTextSearchTool()
    };
  }

  public void onRunComplete(OpenAiApi.Run run) {
    //this is where you'd do something with the run results, such as save messages to a custom object
    System.debug(OpenAiApi.listMessages(run.thread_id));
  }

  public class RunSOQLTool implements IAssistantTool {
    public String execute(Map<String, Object> args) {
      String query = (String) args.get('soql_query');
      if (query == null) {
        throw new AssistantRunQueuable.ToolOuputException('Missing required parameter: soql_query');
      }
      return JSON.serialize(Database.query(query));
    }
  }

  public class FullTextSearchTool implements IAssistantTool {
    public String execute(Map<String, Object> args) {
      String query = (String) args.get('sosl_query');
      if (query == null) {
        throw new AssistantRunQueuable.ToolOuputException('Missing required parameter: sosl_query');
      }

      return JSON.serialize(Search.query(query));
    }
  }
}
