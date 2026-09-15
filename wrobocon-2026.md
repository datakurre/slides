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

- BPMN 2.0: model executable processes
- Operaton: run the process and queue the work
- Robot Worker: execute Robot Tasks with Purjo
- Hello World: build and run a task package
- Testing orchestrated automation end to end
- Wrap-up: resources and next steps

::: notes
Use the agenda to set expectations: first the BPMN notation, then the engine and
worker architecture, followed by a runnable Purjo example and three testing
levels. Close with resources and practical next steps.
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

![](examples/diagrams/bpmn-sequence-flow.bpmn){height="33%" align="center" animated="true" scenario="examples/scenarios/bpmn-sequence-flow.toml"}


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

![](examples/diagrams/bpmn-activity-types.bpmn){height="40%" align="center" animated="true" scenario="examples/scenarios/bpmn-activity-types.toml"}

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

# Robot Worker {.section-slide}

## Robot Tasks as Service Tasks

- BPMN service tasks map to Robot tasks
- Operaton owns state; robots execute
- Workers pull tasks when ready
- Workers "communicate" via process variables

::: notes
In BPMN 2.0, a Service Task is an automated unit of work executed by software.
Operaton uses the External Service Task pattern: it never calls workers directly;
independent Robot Framework workers pull work on demand.
:::

## Service Task in Context

![](examples/diagrams/bpmn-activity-types-robot.bpmn){animated="true" scenario="examples/scenarios/bpmn-activity-types-robot.toml"}

::: notes
Return to the activity sequence: the user task and script task stay in the
process, while the service task becomes work for a Robot Framework worker.
This is the handoff that the topic queue and Purjo configuration implement next.
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

## Purjo `hello.robot`

- Purjo tasks are vanilla `.robot`:

  ```robotframework
  *** Variables ***
  ${BPMN:PROCESS}     local
  ${name}             n/a

  *** Tasks ***
  My Task in Robot
      Log To Console    Hello ${name}!
      VAR    Hello ${name}!  scope=${BPMN:PROCESS}
  ```

## Purjo `pyproject.toml`

```toml
[project]
dependencies = [
    "robotframework>=7.2.2",
]

[dependency-groups]
dev = [
    "robotframework-robotlibrary>=1.0a3",
]

[tool.purjo.topics."My Topic in BPMN"]
name = "My Task in Robot"
process-variables = true
```

## Implicit Process Variable Mapping

- Process variables arrive as Robot variables
- File variables arrive as absolute paths
- No unpacking or adapter code, just Robot

  ```robotframework
  *** Variables ***
  ${name}               ${EMPTY}

  *** Tasks ***
  My Task in Robot
      Log to Console    Hello    ${name}
  ```

## Returning Variables to the Process

- Purjo patches Robot with var scope `BPMN:PROCESS`
- Promote variables to the BPMN process scope
- Operaton receives them when the task completes
- Vanilla Robot Framework with `${BPMN:PROCESS}` indirection

---

# Hello World {.section-slide}

## Running Operaton with Podman

- Build Operaton with community UI plugins

  ```bash
  curl -fsSL https://raw.githubusercontent.com/datakurre/operaton-cockpit-plugins/main/Dockerfile | docker build -t operaton-with-plugins -
  ```

- Run the built image

  ```bash
  docker run --rm -p 8080:8080 operaton-with-plugins
  ```

- Operaton UI credentials: `demo` / `demo`


## Creating a Purjo Task Package

- Scaffold the task, project configuration and example process

  ```bash
  mkdir hello-world
  cd hello-world

  uv run --with=purjo -- pur init --task --agents
  ```

- Deploy a BPMN and start an instance

  ```bash
  uv run --with=purjo -- pur run hello.bpmn
  ```

## Serving a Purjo Task Package

- Poll for the configured topics for tasks
- Run tasks using `uv` in a temporary directory
- Return the logs and results to process

  ```bash
  uv run --with=purjo -- pur serve .
  ```

---

# Demo {.section-slide}

---

# Testing {.section-slide}

## E2E Testing with the `purjo` Library

* Acceptance tests requires running process engine:

  ```robotframework
  *** Settings ***
  Library    purjo
  Library    Collections

  *** Test Cases ***
  Test Topic Execution
      &{inputs}=         Create Dictionary         name=Alice
      &{outputs}=        Get Output Variables      path=.
      ...                topic=My Topic in BPMN    variables=${inputs}
      Should Be Equal    ${outputs}[greeting]      Hello Alice!
  ```

## Testing Task with `RobotLibrary`

* `RobotLibrary` executes just `.robot`:

  ```robotframework
  *** Settings ***
  Library    RobotLibrary

  *** Test Cases ***
  Test Hello Task
      Run Robot Task     hello.robot    My Task in Robot
      ...                BPMN:PROCESS=global
      ...                name=Alice
      Should Be Equal    ${greeting}    Hello Alice!
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
    Complete External Task    ${task_id}        message=Hello Alice!
    Should Be Ended
    [Teardown]                Teardown Process Engine
```

::: notes
[`robotframework-operaton`](https://gitlab.com/vasara-bpm/robotframework-operaton)
:::

---

# Wrap-up {.section-slide}

## Resources

- Operaton: [operaton.org](https://operaton.org)
- Purjo: [pypi.org/project/purjo](https://pypi.org/project/purjo/)
- "Opinionated BPMN 2.0 (bpmn-js) Modeler"
- [pypi.org/project/robotframework-robotlibrary](https://pypi.org/project/robotframework-robotlibrary/)
- [github.com/datakurre/robotframework-operaton](https://github.com/datakurre/robotframework-operaton)

## Summary

- Robot Framework executes the work
- BPMN and Operaton control the process
- Purjo connects workers to topics
- Model, test, and operate locally

---

# Thank you! {.section-slide}
