---
title: "Beyond State"
subtitle: "Complex Business Processes in Plone with BPMN 2.0"
author: Asko Soukka, University of Jyväskylä, Finland
date: Plone Conference 2026, Maastricht
colors:
  primary: "#002957"
  accent: "#F1563F"
aspectratio: "169"
fontsize: 12pt
---

# Introduction {.section-slide}

## State vs. Activity-Based Workflows

::: columns
::: {.column width="50%"}
![](media/ploneconf-2026/images/simple-publication-workflow.png)
:::
::: {.column width="50%"}
![](media/ploneconf-2026/images/activity-based-publication-workflow.bpmn)
:::
:::

## Asko Soukka

::: columns
::: {.column width="30%"}
![](media/ploneconf-2026/images/portrait.jpg)
:::
::: {.column width="65%"}
- Software Architect at University of Jyväskylä, Finland
- Long-time open-source Python and Plone developer
- Building CMS integrations, digital services, and process automation
- BPMN-based process orchestration in production since 2020
:::
:::

## Agenda for Today

![](media/ploneconf-2026/images/agenda.bpmn){animated="true" height="75%"}

---

# State or Activities {.section-slide}

## Previously on...

![](media/ploneconf-2026/images/richter-title.png)

::: {.diagram-caption}
[Stephan Richter, Plone Conf 2016, Making Workflows Work For You](https://www.youtube.com/watch?v=Zu5P53_Pg0E)
:::

## State-Based Workflows

::: columns
::: {.column width="50%"}
![](media/ploneconf-2026/images/simple-publication-workflow.png)
:::
::: {.column width="50%"}
- States and transitions
- Events on transitions
- Chainable and placeful
- Tied to content objects
:::
:::

## Activity-Based Workflows

::: columns
::: {.column width="40%"}
![](media/ploneconf-2026/images/activity-based-publication-workflow.png)
:::
::: {.column width="60%"}
- Activities, sequence flows and gateways
- Intermediate and boundary events
- Call activities, sub-processes and pools
- Process instances and tokens
:::
:::

## The Same, but Different

![](media/ploneconf-2026/images/activity-based-publication-workflow.bpmn){simulator="true"}

## State May Not Be Enough

- **Concurrency**
  - Several actors can work at the same time
- **Timeouts & Events**
  - The process waits for a deadline or webhook
- **Branching & Merging**
  - Decisions create independent parallel paths
- **Task Data & Integrations**
  - Task-specific forms and temporary integrations

## State May Not Be Enough

![](media/ploneconf-2026/images/humantech-workflow.png)

---

# BPMN 2.0 Primer {.section-slide}

## What is BPMN 2.0?

- **Business Process Model and Notation** (OMG standard)
- A visual language understood by business analysts and domain experts
- An executable XML format with strict operational semantics
- Eliminates translation gaps between specification and production code

The diagram is not just documentation. The diagram is the program.

**The diagram is code.**

## Sequence Flow

- ![](bpmn-symbol:startEvent) **Start events** begin a process instance
- ![](bpmn-symbol:endEvent) **End events** finish a path or terminate the instance
- ![](bpmn-symbol:task) **Activities** represent work to be performed
- Flow connects events and activities into an executable path

![](media/ploneconf-2026/diagrams/bpmn-sequence-flow.bpmn){width="60%"}

## Activities

- Activities represent work performed by a person, script, service or process
- The activity type communicates who or what performs the work
- Each activity receives and passes execution onward through sequence flows

![](media/ploneconf-2026/images/bpmn-activity-types.bpmn){height="45%"}

## Token Concept

![](media/ploneconf-2026/diagrams/sample-process.bpmn){animated="true" width="60%"}

- When a process starts, a **token** is generated at the start event
- The token travels along sequence flows into activities
- When an activity completes, the token moves forward
- Gateways can split one token into multiple parallel tokens or merge them
- The instance ends when all active tokens are consumed

## Exclusive Gateways

**Exclusive gateways** ![](bpmn-symbol:exclusiveGateway) choose one path.

![](media/ploneconf-2026/diagrams/bpmn-exclusive-merge.bpmn){simulator="true"}

## Parallel Gateways

**Parallel gateways** ![](bpmn-symbol:parallelGateway) run paths in parallel.

![](media/ploneconf-2026/diagrams/bpmn-parallel-gateway.bpmn){simulator="true"}

## Inclusive Gateways

**Inclusive gateways** ![](bpmn-symbol:inclusiveGateway) activate every matching path.

![](media/ploneconf-2026/diagrams/bpmn-inclusive-merge.bpmn){simulator="true"}

## Timer Boundary Events

::: columns
::: {.column width="50%"}
**Interrupting timers** ![](bpmn-symbol:timerBoundaryEvent) can time out activities and reroute execution.

![](media/ploneconf-2026/diagrams/bpmn-timer-boundary-interrupting.bpmn){simulator="true"}
:::

::: {.column width="50%"}
**Non-interrupting timers** ![](bpmn-symbol:nonInterruptingTimerBoundaryEvent) spawn extra tokens at scheduled intervals.

![](media/ploneconf-2026/diagrams/bpmn-timer-boundary-non-interrupting.bpmn){simulator="true"}
:::
:::

## Error and Message Boundary Events

::: columns
::: {.column width="50%"}
**Error events** ![](bpmn-symbol:errorBoundaryEvent) route "business errors" to recovery paths.

![](media/ploneconf-2026/diagrams/bpmn-error-boundary.bpmn){simulator="true"}
:::
::: {.column width="50%"}
**Message events** ![](bpmn-symbol:messageBoundaryEvent) interrupt tasks when external messages are received.

![](media/ploneconf-2026/diagrams/bpmn-message-boundary.bpmn){simulator="true"}
:::
:::

## External Service Task Pattern

::: columns
::: {.column width="58%"}
![](media/ploneconf-2026/diagrams/external-service-task.bpmn){simulator="true"}
:::
::: {.column width="38%"}
- The engine creates a task for the configured topic
- A worker fetches and locks the service task
- The worker executes the automation and completes the task
- The engine handles retries and failure incidents
:::
:::

**Decoupled execution**. Workers can run anywhere and scale horizontally.

## No Silver Bullet

::: columns
::: {.column width="85%"}
![](media/ploneconf-2026/images/real-life-process.png){border="1px"}
:::

::: {.column width="15%"}
![](media/ploneconf-2026/images/real-life-process-full.png){width="100%" border="1px"}
:::
:::

---

# (FL)OSS Ecosystem {.section-slide}

## BPMN.io

Web-native, extensible tools built and maintained by Camunda and contributors:

::: columns
::: {.column width="48%"}
- **`bpmn-js`**: Web-based BPMN modeler and viewer
- **`@bpmn-io/form-js`**: JSON-based form editor, viewer and playground
- **`dmn-js`**: DMN editing and rendering for decision tables
:::

::: {.column width="48%"}
![](media/ploneconf-2026/images/plone-operaton-modeler.png){border="1px"}
:::
:::

MIT-style bpmn.io license with a mandatory watermark. MIT-licensed plugins.

## Operaton

::: columns
::: {.column width="60%"}
- Apache 2.0-licensed BPMN 2.0 engine
- Community fork of Camunda 7 CE
- Java runtime, Spring-extensible
- Engine, REST API, Web UI
- [start.operaton.org](https://start.operaton.org/)
- [hub.docker.com/r/operaton/operaton](https://hub.docker.com/r/operaton/operaton)
:::

::: {.column width="50%"}
![](media/ploneconf-2026/images/operaton-cockpit-process-definition.png){border="1px"}
:::
:::

## Beyond BPMN.io and Operaton

Different histories and product models; BPMN XML is the common boundary.

- **[jBPM / Apache KIE](https://github.com/kiegroup/jbpm)**: Since 2003; Apache 2.0 Java toolkit with Business Central and Eclipse tooling for modeling, executing and monitoring processes, cases and decisions
- **[Flowable](https://github.com/flowable/flowable-engine)**: Since 2016; Apache 2.0 engines and open-source UI apps, surrounded by a company-led commercial platform; shares Activiti ancestry with Camunda 7
- **[SpiffWorkflow + SpiffArena](https://github.com/sartography/spiff-arena)**: BPMN support since 2020; SpiffArena v1.0 in 2025; LGPLv3 Python BPMN/DMN runtime plus an open-source full-stack web app whose editor extends `bpmn-js`

---

# Demos {.section-slide}

## Engine-Driven

![](media/ploneconf-2026/diagrams/contact-form.bpmn){simulator="true"}

## Content-Driven

![](media/ploneconf-2026/diagrams/review-process.bpmn){simulator="true"}

## Case Management

::: columns
::: {.column width="50%"}
![](media/ploneconf-2026/diagrams/renovation-case.bpmn){simulator="true"}
:::
::: {.column width="50%"}
![](media/ploneconf-2026/diagrams/renovation-page-review.bpmn){simulator="true"}
:::
:::

## Under Construction

### [github.com/collective/collective.bpmproxy](https://github.com/collective/collective.bpmproxy)

::: columns
::: {.column width="32%"}
![](media/ploneconf-2026/images/under-construction.png){width="70%" align="center"}
:::
::: {.column width="63%"}
- BPM Proxy -content type with form views (Blicca)
- Message and Signal content rule actions
- Tasklist portlet with task form vies (Blicca)
- Modeling and deployment controle panel (Blicca)
- Example stack with Operaton, PostgreSQL, Keycloak and browser smoke tests
:::
:::

---

# Thank you! {.section-slide}
