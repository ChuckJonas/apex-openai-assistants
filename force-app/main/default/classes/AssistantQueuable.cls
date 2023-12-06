/**
 * AssistantQueuable
 * 
 * This class is responsible for polling the OpenAI API for the status of a thread run and executes the onRunComplete callback when done
 */
public class AssistantQueuable implements Queueable, Database.AllowsCallouts {
    private String threadId;
    private OpenAiApi.Run run;
    private IAssistant assistant;

    public AssistantQueuable(OpenAiApi.Run run, IAssistant assistant) {
        this.threadId = run.thread_id;
        this.run = run;
        this.assistant = assistant;
    }

    public void execute(QueueableContext context) {
      poll();
    }

    public void poll() {
         // Logic to retrieve and process the run
         run = OpenAiApi.getRun(threadId, run.id);

         System.Debug('ThreadId: ' +  threadId);
         System.debug('Run status: ' + run.status);
 
         if (run.status == 'queued' || run.status == 'in_progress') {
             // Re-enqueue the job for further polling
             pollOrQueue();
         } else if (run.status == 'requires_action') {
             // TODO: Add BEFORE RUN ACTION hook to allow for things like asking for confirmation, etc
             handleActionRequired();
             pollOrQueue();
         } else {
             // run processing complete... do something with the results?
             assistant.onRunComplete(run);
         }
    }

    private void pollOrQueue(){
        System.debug('CALLOUTS: ' + Limits.getCallouts() + ' / ' + Limits.getLimitCallouts());
        System.debug('CPU TIME: ' + Limits.getCpuTime() + ' / ' + Limits.getLimitCpuTime());
        if(Limits.getCallouts() < Limits.getLimitCallouts() - 5 && Limits.getCpuTime() < Limits.getLimitCpuTime() - 1500){
        
            sleep(500);
            poll();
            return;
        }

        System.enqueueJob(new AssistantQueuable(run, assistant));
    }


    private void handleActionRequired() {
        System.debug('Run requires action');
        List<OpenAiApi.ToolOutput> toolOutputs = new List<OpenAiApi.ToolOutput>();
        Map<String, IAssistantTool> toolBox = assistant.getToolBox();
        
        for (OpenAiApi.ToolCall toolCall : this.run.required_action.submit_tool_outputs.tool_calls) {
            System.debug('Handling tool call: ' + toolCall.function.name);
            OpenAiApi.ToolOutput output = new OpenAiApi.ToolOutput(toolCall.id);
           
           try{
            IAssistantTool tool = toolBox.get(toolCall.function.name);
            Map<String, Object> parsedArgs = (Map<String, Object>) JSON.deserializeUntyped(toolCall.function.arguments);
            output.output = tool.execute(parsedArgs);
           }catch(Exception e){
            // TODO: create special exception which tools can raise to send exceptional output back to OpenAI
            //  otherwise we should error out 
            output.output = e.getMessage();
           }
           toolOutputs.add(output);
        
        }
        System.debug('Submitting tool outputs');

        OpenAiApi.submitToolOutputs(threadId, run.id, toolOutputs);
    }

    //TODO: find better way to sleep?
    // Biggest problem with this is it crushes the log files
    // https://salesforce.stackexchange.com/a/218304/3341
    private static void sleep(Integer ms) {
        Long epochToDate = System.currentTimeMillis();
        while (epochToDate <= epochToDate + ms) {
            // do something expensive here to actually slow it down?
            epochToDate = System.currentTimeMillis();
        }
    }

}
