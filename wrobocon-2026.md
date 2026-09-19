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

## Automation Control Plane

![](examples/diagrams/automation-control-plane.bpmn){simulator="true" scenario="examples/scenarios/automation-control-plane.toml"}

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

## Orchestration Challenge

- A task is easy, a process is not
- Real work needs state, branching, and waiting
- Real work crosses systems and includes humans
- BPMN makes the flow visible and executable

## Agenda

- BPMN 2.0: model executable processes
- Operaton: run the process and queue the work
- Robot Worker: execute Robot Tasks with Purjo
- Hello World: build and run a task package
- Testing orchestrated automation end to end
- Wrap-up: resources and summary

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
- Activities: the work happens
- End: the process reaches an outcome
- Tokens: visualize the execution and state

![](examples/diagrams/bpmn-sequence-flow.bpmn){height="30%" align="center" animated="true" scenario="examples/scenarios/bpmn-sequence-flow.toml"}

## Activities

- Activities are units of work
- User Tasks, Script Tasks, Service Tasks, ...
- Humans, engine, or robots can perform them
- Sequence flows connect the work

![](examples/diagrams/bpmn-activity-types.bpmn){height="30%" align="center" animated="true" scenario="examples/scenarios/bpmn-activity-types.toml"}

## Control Flow

- Gateways steer, split or merge
- Exclusive (**XOR**) chooses one path
- Parallel (**AND**) runs paths in parallel
- Inclusive (**OR**) activates every matching path

## Exclusive Gateways

![](examples/diagrams/bpmn-exclusive-merge.bpmn){animated="true" scenario="examples/scenarios/bpmn-exclusive-merge.toml"}

## Parallel Gateways

![](examples/diagrams/bpmn-parallel-gateway.bpmn){animated="true" scenario="examples/scenarios/bpmn-parallel-gateway.toml"}

## Inclusive Gateways

![](examples/diagrams/bpmn-inclusive-merge.bpmn){animated="true" scenario="examples/scenarios/bpmn-inclusive-merge.toml"}

## Exception Handling

- Attach an event to the work
- Timers handle deadlines
- Errors handle business exceptions

![](examples/diagrams/bpmn-boundary-events.bpmn){height="100%" simulator="true" scenario="examples/scenarios/bpmn-boundary-events.toml"}

## One more BPMN example

![](examples/diagrams/data-analysis.bpmn){scenario="examples/scenarios/data-analysis.toml"}

---

# Process Engine {.section-slide}

## Why BPMN for Developers?

- Visual communication language for everyone
- **BPMN / Engine** controls flow and state
- **Robot Framework** implements task automation
- Small workers stay focused and reusable
- The engine provides tools and logs

## Introducing Operaton

- Open-source BPMN 2.0 workflow engine
- A community fork of Camunda 7 Community Edition
- A Java runtime with a REST API and Web UI
- [start.operaton.org](https://start.operaton.org/)
- [hub.docker.com/r/operaton/operaton](https://hub.docker.com/r/operaton/operaton)

## The External Task Pattern

- The engine queues work; workers pull it
- Topics decouple orchestration from execution
- Workers run anywhere and scale horizontally
- Operaton provides a REST API with long polling

![](examples/diagrams/bpmn-activity-types.bpmn){height="30%" align="center" animated="true" scenario="examples/scenarios/bpmn-activity-types.toml"}

---

# Robot Worker {.section-slide}

## Robot Tasks as Service Tasks

- Map BPMN service tasks to Robot tasks
- Operaton owns state; robots task execution
- Workers poll, fetch and complete tasks
- Tasks "communicate" by process variables

![](examples/diagrams/bpmn-activity-types-robot.bpmn){height="30%" animated="true" scenario="examples/scenarios/bpmn-activity-types-robot.toml"}

## Service Tasks as Queues

- A topic names the work: `update-system`
- Operaton queues work under that topic
- Multiple workers can share the queue
- The same topic can be reused in BPMN

![](examples/diagrams/bpmn-activity-types-robot.bpmn){height="30%" animated="true" scenario="examples/scenarios/bpmn-activity-types-robot.toml"}

## External Task Worker

- Fetch and lock a task
- Receive process variables
- Execute the Robot task
- Return variables to process

![](examples/diagrams/bpmn-activity-types-robot.bpmn){height="30%" animated="true" scenario="examples/scenarios/bpmn-activity-types-robot.toml"}

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
      Log To Console        Hello ${name}!
      VAR    ${greeting}    Hello ${name}!    scope=${BPMN:PROCESS}
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

  ```robotframework
  *** Variables ***
  ${name}               ${EMPTY}

  *** Tasks ***
  My Task in Robot
      Log to Console    Hello    ${name}
  ```

## Returning Variables to the Process

- Purjo patches Robot with `VAR` scope `BPMN:PROCESS`
- Operaton receives them when the task completes
- Vanilla `robot` supported by`${BPMN:PROCESS}` indirection

  ```robotframework
  *** Variables ***
  ${BPMN:PROCESS}     local

  *** Tasks ***
  My Task in Robot
      VAR    ${greeting}    Hello World!    scope=${BPMN:PROCESS}
  ```

---

# Hello World {.section-slide}

## Running Operaton with Podman

- Build Operaton with community UI plugins

  ```bash
  curl -fsSL https://raw.githubusercontent.com/\
  datakurre/operaton-cockpit-plugins/main/\
  Dockerfile | docker build -t operaton-with-plugins -
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
  uv run --with=purjo -- pur serve . --log-level=DEBUG
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

- Robot Framework for task automation
- BPMN and Operaton for control plane
- Purjo connects Robot tasks to BPMN
- Operaton and bpmn.io ecosystems

---

# Thank you! {.section-slide}
