# Apex OpenAI Assistants

Library for working with OpenAI Assistants in Salesforce Apex. 

WIP. Incomplete & API likely to change.

## Setup

1. Install
2. Configure Named Credential for OpenAI API

## Usage

### Configure the Assistant

1. Create an OpenAI Assistant (using Open AI Playground).  Grab the assistant ID for later.
2. Define an `IAssistant` with matching "tools" and an handle to execute after each "run" completion

```java
public class DemoAssistant implements IAssistant  {

    public static String ASSISTANT_ID = 'YOUR_ASSISTANT_ID';

    public Map<string, IAssistantTool> getToolBox(){
        return new Map<String, IAssistantTool> {
            'run_soql' => new RunSOQLTool()
        };
    }

    public void onRunComplete(OpenAiApi.Run run){
        System.debug(OpenAiApi.listMessages(run.thread_id));
    }
    
    public class RunSOQLTool implements IAssistantTool {
        public String execute(Map<String, Object> args) {
            String query = (String) args.get('query');
            return JSON.serialize(Database.query(query));
        }
    }
}
```

### Run The Assistant

```java
OpenAiApi.RequestMessage[] messages = new OpenAiApi.RequestMessage[] {
    new OpenAiApi.RequestMessage('user', 'Give me the last account created'),
};

String threadId = OpenAiApi.createThread(DemoAssistant.ASSISTANT_ID, messages, null);
OpenAiAPI.Run run = OpenAiApi.createRun(threadId, DemoAssistant.ASSISTANT_ID);

// Poll the run
AssistantQueuable poller = new AssistantQueuable(run, new DemoAssistant());
```

Later, you may add more messages and run again:

```java
String threadId = ''; //... you'd need to persist the threadId somewhere
OpenAiApi.createMessage(threadId, new OpenAiApi.RequestMessage('user', 'Give me the last contact created'));
OpenAiAPI.Run run = OpenAiApi.createRun(threadId, assistantId);
AssistantQueuable poller = new AssistantQueuable(run, new DemoAssistant());
```
