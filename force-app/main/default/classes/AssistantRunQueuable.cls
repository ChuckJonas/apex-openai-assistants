/**
 * AssistantQueuable
 *
 * This class is responsible for polling the OpenAI API for the status of a thread run and executes the onRunComplete callback when done
 */
public class AssistantRunQueuable implements Queueable, Database.AllowsCallouts {
  private String threadId;
  private OpenAiApi.Run run;
  private IAssistant assistant;

  private static final Integer DELAY_MS = 1000;

  public AssistantRunQueuable(String threadId, IAssistant assistant) {
    this.threadId = threadId;
    this.assistant = assistant;
  }

  public AssistantRunQueuable(OpenAiApi.Run run, IAssistant assistant) {
    this.threadId = run.thread_id;
    this.run = run;
    this.assistant = assistant;
  }

  public void startRun() {
    if (run != null) {
      throw new AssistantQueuableException('Run already started');
    }

    //todo: check context to make sure we can callout
    run = OpenAiApi.createRun(threadId, assistant.getAssistantId());
    pollOrQueue();
  }

  public void execute(QueueableContext context) {
    poll();
  }

  public void poll() {
    // Logic to retrieve and process the run
    run = OpenAiApi.getRun(threadId, run.id);

    System.Debug('ThreadId: ' + threadId);
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

  private void pollOrQueue() {
    System.debug('CALLOUTS: ' + Limits.getCallouts() + ' / ' + Limits.getLimitCallouts());
    System.debug('CPU TIME: ' + Limits.getCpuTime() + ' / ' + Limits.getLimitCpuTime());
    if (
      Limits.getCallouts() < Limits.getLimitCallouts() - 10 &&
      Limits.getCpuTime() < Limits.getLimitCpuTime() - DELAY_MS * 5
    ) {
      sleep(DELAY_MS);
      poll();
      return;
    }

    System.enqueueJob(new AssistantRunQueuable(run, assistant));
  }

  private void handleActionRequired() {
    System.debug('Run requires action');
    List<OpenAiApi.ToolOutput> toolOutputs = new List<OpenAiApi.ToolOutput>();
    Map<String, IAssistantTool> toolBox = assistant.getToolBox();

    for (OpenAiApi.ToolCall toolCall : this.run.required_action.submit_tool_outputs.tool_calls) {
      System.debug('Handling tool call: ' + toolCall.function.name);
      OpenAiApi.ToolOutput output = new OpenAiApi.ToolOutput(toolCall.id);

      try {
        IAssistantTool tool = toolBox.get(toolCall.function.name);
        if (tool == null) {
          throw new ToolOuputException('Tool not found: ' + toolCall.function.name);
        }
        system.debug(toolCall.function.arguments);
        Map<String, Object> parsedArgs = (Map<String, Object>) JSON.deserializeUntyped(toolCall.function.arguments);
        output.output = tool.execute(parsedArgs);
      } catch (System.JSONException e) {
        output.output = 'Failed to parse arugments JSON.  Please make sure json is valid.';
      } catch (ToolOuputException e) {
        System.Debug('ToolOuputException: ' + e.getMessage());
        output.output = e.getMessage();
      } catch (Exception e) {
        throw e;
      }
      toolOutputs.add(output);
      System.debug(output);
    }
    System.debug('Submitting tool outputs');

    OpenAiApi.submitToolOutputs(threadId, run.id, toolOutputs);
  }

  //TODO: find better way to sleep?
  // Biggest problem with this is it crushes the log files
  // https://salesforce.stackexchange.com/a/218304/3341
  public static void sleep(Integer ms) {
    Long epochToDate = System.currentTimeMillis();
    Long epochStop = epochToDate + ms;

    while (epochToDate <= epochStop) {
      epochToDate = System.currentTimeMillis();
    }
  }

  /**
   * Use this class to return an error message to Assistant
   */
  public class ToolOuputException extends Exception {
  }

  public class AssistantQueuableException extends Exception {
  }
}
