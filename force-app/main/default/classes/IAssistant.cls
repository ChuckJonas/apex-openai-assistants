public interface IAssistant {
  string getAssistantId();
  Map<string, IAssistantTool> getToolBox();
  void onRunComplete(OpenAiApi.Run run);
}
