# Apex OpenAI Assistants

Library for working with OpenAI Assistants in Salesforce Apex. 

**Warning: WIP. Incomplete & API likely to change.**

## Setup

0. Sign-up for OpenAI and create an API key
1. Install
2. Configure Named Credential for OpenAI API
3. Assign Permission set `sfdx force:user:permset:assign -n OpenAI`

## Usage

### Configure the Assistant

1. Create an OpenAI Assistant (using Open AI Playground).  Grab the assistant ID for later.

<img width="300" alt="Assistants_-_OpenAI_API" src="https://github.com/ChuckJonas/apex-openai-assistants/assets/5217568/fa8b9b1a-5bfa-462f-8a56-196f80ffa364">

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
        //this is where you'd do something with the run results, such as save messages to a custom object
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
    new OpenAiApi.RequestMessage('user', 'Give me the last account created')
};

String threadId = OpenAiApi.createThread(messages, null);
OpenAiAPI.Run run = OpenAiApi.createRun(threadId, DemoAssistant.ASSISTANT_ID);

// Poll the run
AssistantQueuable runQueuable = new AssistantQueuable(run, new DemoAssistant());
System.enqueueJob(runQueuable);
```

Later, you may add more messages and run again:

```java
String threadId = '...'; // you'd need to persist the threadId somewhere
OpenAiApi.createMessage(threadId, new OpenAiApi.RequestMessage('user', 'Give me the last contact created'));
OpenAiAPI.Run run = OpenAiApi.createRun(threadId, assistantId);
AssistantQueuable poller = new AssistantQueuable(run, new DemoAssistant());
```


### How to integrate with a Client UI

In order to build a client UI in Salesforce that can interact with the assistant, you'll likely want to create a custom object(s) that tracks the threads and gets updated each time a run completes.  This would make it easier to trigger UI updates when the run completes.  It also allows you to persist the threadId so that you can add messages to the thread later.  

Alternatively, you could just have the client itself poll `OpenAIApi.getRun(runId)` until the run `status=complete`. 

