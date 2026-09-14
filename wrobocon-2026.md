---
title: FOSS Automation Control Plane
subtitle: Orchestrating Robot Framework RPA and Task Automation with BPMN
author: Asko Soukka, University of Jyväskylä, Finland
date: 2026, Wrobocon
colors:
  primary: "#002957"
  accent: "#F1563F"
aspectratio: "169"
fontsize: 14pt
---

# Introduction {.section-slide}

::: notes
Start with a minimal demo.

Present yourself.

Present the agenda.
:::

## Automation Control Plane

![](examples/diagrams/automation-control-plane.bpmn){animated="true" scenario="examples/scenarios/automation-control-plane.toml"}

::: notes
Start with the demo or recording when available.
:::

## Asko Soukka (RFCP®)

::: columns
::: {.column width="30%"}
![](images/portrait.jpg)
:::
::: {.column width="60%"}
- Software Architect at University of Jyväskylä, Finland
- Decades of experience in open-source Python development
- CMS deployments, microservices, Robot Framework tasks and tests
- BPMN-based automation and process orchestration since 2020
:::
:::

## Robot Framework for RPA

- From test automation to RPA
- Keywords make complex actions readable
- Execution logs make automation auditable
- An open ecosystem for almost any system
- [robotframework.org/rpa](https://robotframework.org/rpa)

::: notes
Robot Framework was designed for keyword-driven testing, but the same model works
well for repetitive business tasks. Its ecosystem covers browsers, APIs, documents,
images, spreadsheets, and more. Point people to [robotframework.org/rpa](https://robotframework.org/rpa).
:::

## Orchestration Challenge

- A task is easy, a process is not
- Real work needs state, branching, and waiting
- Real work crosses systems and includes humans
- BPMN makes the flow visible and executable

::: notes
A single script can automate one action, but production work crosses systems and
often pauses for people, timers, or external events. Scripts alone make progress,
retries, and failures difficult to inspect. BPMN supplies that missing control plane.
:::

## Agenda

- BPMN as the control plane
- Operaton, Purjo, and Robot Framework
- Build, test, model, and operate

::: notes
The detailed route is: BPMN 2.0 primer; Operaton and external service tasks;
Robot Framework through Purjo; a Hello World walkthrough and testing; then
in-editor modeling tools and live operations.
:::

---

# BPMN 2.0 {.section-slide}

## What is BPMN 2.0?

- Business Process Model and Notation (ISO/IEC 19510)
- A standard language for executable processes
- Visual for people, precise for engines
- A mature ecosystem of tools and runtimes

::: notes
BPMN means Business Process Model and Notation and is standardized as ISO/IEC 19510.
Unlike an informal flowchart, it has formal execution semantics. Models can be
reviewed as documentation and deployed as executable process definitions.
:::

## Sequence Flow

- Start: something triggers the process
- Activities: work happens
- End: the process reaches an outcome
- Tokens: visualize the execution and state

::: notes
Sequence flows connect these elements and describe the path from process start to
outcome. Use the next diagram to introduce the notation from left to right.
:::

## Sequence Flow Example

![](examples/diagrams/bpmn-sequence-flow.bpmn){animated="true" scenario="examples/scenarios/bpmn-sequence-flow.toml"}

## Activities

- Activities are units of work
- Manual tasks, forms, scripts, queues, decisions, ...
- People, systems, or robots can perform them
- Sequence flows connect the work

::: notes
The activity type communicates who or what performs the work. The next example
contrasts user, script, and service tasks.
:::

## Activities Example

![](examples/diagrams/bpmn-activity-types.bpmn){animated="true" scenario="examples/scenarios/bpmn-activity-types.toml"}

## Control Flow

- Gateways steer, split or merge
- **XOR** chooses one path
- **AND** runs paths in parallel
- **OR** activates every matching path

::: notes
An exclusive gateway chooses one outgoing path using a condition such as
`${orderValid}`. A parallel gateway splits execution and later synchronizes it.
An inclusive gateway activates one or more paths whose conditions are true.
:::

## Control Flow Steering Example

![](examples/diagrams/bpmn-exclusive-merge.bpmn){animated="true" scenario="examples/scenarios/bpmn-exclusive-merge.toml"}

## Control Flow Splitting Example

![](examples/diagrams/bpmn-parallel-gateway.bpmn){animated="true" scenario="examples/scenarios/bpmn-parallel-gateway.toml"}

## Exception Handling

- Attach an event to the work that needs protection
- Interrupting or non-interrupting
- Timers handle deadlines
- Errors handle business exceptions

::: notes
A boundary event is attached to an activity. A timer can interrupt or redirect
work after a deadline; an error event catches a business error. The normal path
handles success while the boundary path handles the exception.
:::

## Exception Handling Example

![](examples/diagrams/bpmn-boundary-events.bpmn){animated="true" scenario="examples/scenarios/bpmn-boundary-events.toml"}

## More Comprehensive Example

![](examples/diagrams/data-analysis.bpmn){scenario="examples/scenarios/data-analysis.toml"}

::: notes
Walk through the process from left to right. Point out the cloud workspace
setup, dataset decision, parallel staging, processing subprocess, and the
compensation handler that deletes the workspace.
:::

---

# Process Engine {.section-slide}

## Why BPMN for Developers?

- Everyone can inspect the process
- The diagram is the executable flow
- BPMN controls the flow; code performs the work
- The engine provides tools and logs

::: notes
The model becomes an executable specification rather than documentation that can
drift from the code. Developers keep task implementation in code while BPMN owns
flow and state. This also gives non-developers a reviewable view of the workflow.
:::

## Separation of Concerns

- **BPMN / Engine** controls flow and state
- **Robot Framework** performs system actions
- Small workers stay focused and reusable
- "Orchestrated Distributed Worker Architecture"

::: notes
Operaton sequences steps, manages tokens, resolves gateways, and tracks state.
Robot Framework interacts with browsers, APIs, files, and other systems through
keywords. The separation keeps workers small, stateless, and single-purpose.
:::

## Introducing Operaton

- Open-source BPMN 2.0 workflow engine
- A community fork of Camunda 7 Community Edition
- A Java runtime with a REST API and Web Cockpit
- [start.operaton.org](https://start.operaton.org/)
- [hub.docker.com/r/operaton/operaton](https://hub.docker.com/r/operaton/operaton)

::: notes
Operaton executes BPMN processes and decisions. It is a community fork of Camunda
7 Community Edition, with a mature Java runtime, REST API, and Web Cockpit. It can
serve as the control plane for polyglot services and automation workers.
:::

## The External Task Pattern

- The engine queues work; workers pull it
- Topics decouple orchestration from execution
- Workers run anywhere and scale horizontally
- Operaton provides a REST API with long polling

::: notes
The engine never calls workers directly. Workers poll subscribed topic names,
which is firewall-friendly and works on laptops, bare metal, or containers.
:::

---

# Robot Task Worker {.section-slide}

## Robots as Service Tasks

- BPMN service tasks map to Robot tasks
- Operaton owns state; robots execute
- Workers pull tasks when ready
- Workers "communicate" via process variables

::: notes
In BPMN 2.0, a Service Task is an automated unit of work executed by software.
Operaton uses the External Service Task pattern: it never calls workers directly;
independent Robot Framework workers pull work on demand.
:::

## Service Tasks as Queues

- A topic names the work: `validate-order`
- Operaton queues work under that topic
- Multiple workers can share the queue
- The same topic can be reused in BPMN

::: notes
Each external service task specifies a topic name. When execution reaches the task,
Operaton creates a work item in that topic's queue. Multiple workers can subscribe
to the same topic to scale horizontally.
:::

## External Task Worker

- Fetch and lock a task
- Receive process or scoped variables
- Execute the Robot task
- Return variables, or report a failure or error

::: notes
The worker polls the topic queue and acquires a task with a lock timeout. Operaton
passes the process variables; Robot executes browser, API, desktop, or script
keywords. Completion returns output variables. Errors and timeouts can trigger
retries or BPMN error boundaries.
:::

## Introducing Purjo

- Purjo connects Operaton topics to Robot tasks
- Isolated environments provided via `uv`
- Topic mappings live in `pyproject.toml`
- Injects variables and secrets; adds return scope

## Purjo `pyproject.toml`

```toml
[project]
...

[tool.purjo.topics."My Topic in BPMN"]
name = "My Task in Robot"
process-variables = true
on-fail = "ERROR"
```

## Implicit Process Variable Mapping

- Process variables arrive as Robot variables
- File variables arrive as absolute paths
- No unpacking or adapter code, just Robot
- Example: `${name}`

::: notes
Purjo injects Operaton process variables directly into Robot Framework. An
Operaton variable named `name` is available as `${name}` in the task.
:::

## Returning Variables to the Process

- Purjo patches Robot with var scope `BPMN:PROCESS`
- Promote variables to the BPMN process scope
- Operaton receives them when the task completes
- Supports vanilla Robot Framework with `${BPMN:PROCESS}` indirection

::: notes
Standard Robot VAR scopes only exist within the local runner. Purjo adds
`scope=BPMN:PROCESS`, so output variables are captured and returned to Operaton.
:::

## Purjo `hello.robot`

```robotframework
*** Variables ***
${BPMN:PROCESS}     local
${name}             n/a

*** Tasks ***
My Task in Robot
    Log To Console    Hello ${name}!
    VAR    Hello ${name}!  scope=${BPMN:PROCESS}
```

---

# Hello World {.section-slide}

## Running Operaton with Podman

- Build Operaton with commmunity UI plugins

  ```bash
  curl -fsSL https://raw.githubusercontent.com/datakurre/operaton-cockpit-plugins/main/Dockerfile | docker build -t operaton-with-plugins -
  ```

- Run the built image

  ```bash
  docker run --rm -p 8080:8080 operaton-with-plugins
  ```

- Username: `demo`, password: `demo`

::: notes
The Dockerfile is built directly from GitHub. The demo credentials are `demo` /
`demo`. The container exposes the Web Cockpit and engine REST API on port 8080.
:::


## Creating a Purjo Task Package

- Scaffold the process, task, and project configuration

  ```bash
  mkdir hello-world
  cd hello-world

  uv run --with=purjo -- pur init --task --agents
  ```

- Deploy a BPMN and start an instance

  ```bash
  uv run --with=purjo -- pur run hello.bpmn
  ```

::: notes
`pur run` deploys `hello.bpmn` through the REST API, creates a process instance,
and returns a direct Cockpit URL. The instance waits at the external task topic.
:::


## Serving a Purjo Task Package

- Poll for the configured topic
- Run `hello.robot` using `uv` in a temporary directory
- Return the logs and results to Operaton

  ```bash
  uv run --with=purjo -- pur serve .
  ```

::: notes
`pur serve` polls Operaton, locks matching tasks, runs `hello.robot` through `uv`,
logs output, and submits the result so the workflow can continue.
:::

---

# Testing Orchestrated Automation {.section-slide}

## E2E Testing with the `purjo` Library

```robotframework
*** Settings ***
Library    Purjo
Library    Collections

*** Test Cases ***
Test Topic Execution
    &{inputs}=         Create Dictionary         name=Alice
    &{outputs}=        Get Output Variables      path=.
    ...                topic=My Topic in BPMN    variables=${inputs}
    Should Be Equal    ${outputs}[greeting]      Hello Alice!
```

## Testing Task with `RobotLibrary`

```robotframework
*** Settings ***
Library    RobotLibrary

*** Test Cases ***
Test Hello Task
    Run Robot Task     hello.robot    My Task in Robot
    ...                BPMN:PROCESS=global
    ...                name=John Doe
    Should Be Equal    ${greeting}    Hello John Doe!
```

## Testing BPMN with `Operaton` Library

```robotframework
*** Settings ***
Library    Operaton

*** Test Cases ***
Hello Process Completes External Task
    [Setup]                   Setup Process Engine
    Deploy Resources          ${CURDIR}${/}hello.bpmn
    Start Instance            example-hello-world
    ${tasks}=                 Fetch And Lock    My Topic in BPMN
    ${task_id}=               Get From List     ${tasks}    0
    Complete External Task    ${task_id}    message=Hello Alice!
    Should Be Ended
    [Teardown]                Teardown Process Engine
```

::: notes
[`robotframework-operaton`](https://gitlab.com/vasara-bpm/robotframework-operaton)
embeds Operaton with an in-memory H2 database, avoiding network overhead. The
watch mode reruns tests when `.robot` or `.bpmn` files change.
:::

---

# Wrap-up {.section-slide}

## Resources

- Operaton: [operaton.org](https://operaton.org)
- Purjo: [pypi.org/project/purjo](https://pypi.org/project/purjo/)
- "Opinionated BPMN 2.0 (bpmn-js) Modeler"
- [pypi.org/project/robotframework-robotlibrary](https://pypi.org/project/robotframework-robotlibrary/)
- [github.com/datakurre/robotframework-operaton](https://github.com/datakurre/robotframework-operaton)

::: notes
- [Opinionated BPMN Modeler](https://marketplace.visualstudio.com/items?itemName=datakurre.vscode-operaton-bpmn-js-modeler) (VSCode)

The VS Code modeler keeps `.bpmn` models and `.robot` suites together, with token
simulation and linting while editing. RobotCode adds language-server support,
debugging, and test execution. `bpmn-autolayout` and `bpmn-to-image` automate
diagram layout and SVG/PDF rendering for CI.
:::

## Summary

- Robot Framework executes the work
- BPMN and Operaton control the process
- Purjo connects workers to topics
- Model, test, and operate locally

---

# Thank you! {.section-slide}
