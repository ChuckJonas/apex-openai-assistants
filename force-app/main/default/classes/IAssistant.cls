public interface IAssistant {
    Map<string, IAssistantTool> getToolBox();
    void onRunComplete(OpenAiApi.Run run);
}