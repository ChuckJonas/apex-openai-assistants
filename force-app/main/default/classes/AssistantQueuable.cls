/**
 * AssistantQueuable
 * 
 * This class is responsible for polling the OpenAI API for the status of a thread run and executes the onRunComplete callback when done
 */
public class AssistantQueuable implements Queueable {
    private String threadId;
    private OpenAiApi.Run run;
    private IAssistant assistant;

    public AssistantQueuable(OpenAiApi.Run run, IAssistant assistant) {
        this.threadId = run.thread_id;
        this.run = run;
        this.assistant = assistant;
    }

    public void execute(QueueableContext context) {
        // Logic to retrieve and process the run
        run = OpenAiApi.getRun(threadId, run.id);

        if (run.status == 'queued' || run.status == 'in_progress') {
            // Re-enqueue the job for further polling
            scheduleNextPoll();
        } else if (run.status == 'requires_action') {
            // TODO: Add BEFORE RUN ACTION hook to allow for things like asking for confirmation, etc
            handleActionRequired();
            scheduleNextPoll();
        } else {
            // run processing complete... do something with the results?
            assistant.onRunComplete(run);
        }
    }

    private void scheduleNextPoll(){
        System.enqueueJob(new AssistantQueuable(run, assistant), 1);
    }

    private void handleActionRequired() {
        System.debug('Run requires action');
        List<OpenAiApi.ToolOutput> toolOutputs = new List<OpenAiApi.ToolOutput>();
        Map<String, IAssistantTool> toolBox = assistant.getToolBox();
        for (OpenAiApi.ToolCall toolCall : this.run.requiredAction.submitToolOutputs.toolCalls) {
            System.debug('Handling tool call: ' + toolCall.function.name);
            OpenAiApi.ToolOutput output = new OpenAiApi.ToolOutput(toolCall.tool_call_id);
           
           try{
            IAssistantTool tool = toolBox.get(toolCall.function.name);
            Map<String, Object> parsedArgs = (Map<String, Object>) JSON.deserializeUntyped(toolCall.function.args);
            output.output = tool.execute(parsedArgs);
           }catch(Exception e){
            // TODO: create special exception which tools can raise to send exceptional output back to OpenAI
            //  otherwise we should error out 
            output.output = e.getMessage();
           }
        
        }
        System.debug('Submitting tool outputs');

        OpenAiApi.submitToolOutputs(threadId, run.id, toolOutputs);
    }

    public interface IHandleComplete {
        void execute(AssistantQueuable poller);
    }
}
