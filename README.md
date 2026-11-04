# EUROPESIP custom MCP Server for HCL DX IQ

[Español](README.es.md)

**A skeleton to build your own MCP Server and extend HCL DX IQ with your own tools.**

HCL DX IQ comes with an MCP Server from HCL that gives the assistant its DX tools. IQ can also call
**other MCP Servers**, and that is where its real possibilities are: your own knowledge, your own
systems and your own actions, available from the IQ chat.

This repository is an example of that, not a product. It is small (one Python file,
[server.py](server.py), commented section by section), works as is, and is meant to be copied:
replace the EUROPESIP tools with yours and you have the base of your own server. It is the custom
MCP Server of **Lab 3B** of the
[HCL DX Compose labs](https://github.com/europesip/hcl-dx-compose-labs), whose
[Lab 3 guide](https://github.com/europesip/hcl-dx-compose-labs/blob/main/lab3-iq-openrouter/GUIDE.md)
explains how to deploy it and register it in IQ. It is not HCL software.

## How IQ uses it

```
 user ──► IQ chat ──► IQ Integrator ──► LLM                (decides which tool to call)
                          ├─► HCL MCP Server               (DX tools)
                          └─► this MCP Server   /mcp       (your tools)
```

1. When the IQ Integrator starts, it asks every MCP Server in its list for its tools (`tools/list`).
2. On every question, the LLM reads the tool descriptions and decides whether to call one
   (`tools/call`).
3. IQ writes the answer with what the tool returned, in the user's language.

On every `tools/call` the Integrator also forwards **the DX session cookies of the user asking**, so
a tool can call DX with that user's identity and permissions.

## The five example tools

Each one shows a different pattern:

| Tool | What it does | Pattern it shows |
|---|---|---|
| `europesip_services()` | Who EUROPESIP is and which services it offers | The simplest tool: no parameters, a fixed answer |
| `europesip_faq(topic)` | Support hours, AI, digital sovereignty, labs, contact... | A parameter filled in by the LLM, and a knowledge-base lookup (the tool to replace with your own data) |
| `figma_web_to_dx(source)`, shown as **figma&web-to-dx** | Presents the EUROPESIP tool that builds WCM / Blueprint components from Figma, screenshots or URLs | A technical name (`[a-zA-Z0-9_-]` only) different from the display name |
| `europesip_whoami()` | Who the user asking is, read from DX | **Calling DX as the user asking**, with the session forwarded by the Integrator |
| `europesip_echo(text)` | Returns the text it receives | Diagnostics of the whole path, without the LLM interpreting anything |

Every answer ends with a short instruction asking the model to use only that information: without
it, the model tends to "embellish" company data.

## Example questions

Ask them in the IQ chat, in English or in your language (IQ translates the answers):

| Question | Tool IQ calls |
|---|---|
| Who is EUROPESIP and what services does it offer? | `europesip_services` |
| What are the EUROPESIP support hours? | `europesip_faq` (topic `support`) |
| What does EUROPESIP think about digital sovereignty? | `europesip_faq` (topic `sovereignty`) |
| Where can I find the EUROPESIP labs to install DX Compose? | `europesip_faq` (topic `labs`) |
| How can I contact EUROPESIP? | `europesip_faq` (topic `contact`) |
| I want to create a Blueprint component from this Figma design: https://www.figma.com/design/... | `figma_web_to_dx` |
| Who am I? / Which user am I logged in as? | `europesip_whoami` |
| Test the EUROPESIP echo with "hello" | `europesip_echo` |

Questions about DX itself ("Which WCM libraries are there?") still go to the HCL MCP Server: both
servers work side by side.

## Keep in mind: the HCL system prompt

Your tools do not talk to the LLM on their own. The IQ Integrator puts the HCL system prompt in
front of every request (about 3,600 tokens in IQ 1.0.2; you can read it in the LiteLLM log), and its
guardrails apply to your tools too:

- **Request routing: INQUIRY vs ACTION.** The model must classify every request. Questions
  ("What / How / Why / Can I / Is it possible...") are *inquiry*: "answer from DX knowledge, NO
  tools". Commands ("List / Show / Create / Get / Update / Delete...") are *action*: use the tools
  on the live system.
- **The action mode is written around the HCL tools.** It maps each intent to an HCL tool and, when
  none matches, tells the model to answer "I don't have a tool for [operation]".
- **The assistant is scoped to HCL DX.** Its identity is a DX assistant, it must not invent
  features, and its refusals are worded for DX topics.
- **Every answer is JSON** (`answer` plus `metadata`), which the IQ chat renders. Your tool returns
  plain text; the model puts it into that format.

In our tests the inquiry-style questions of the table above (*"Who is EUROPESIP...?"*, *"What are
the support hours?"*) did call the custom tools: the model gives priority to a tool whose
description matches the question. But that is the model weighing your tool against an explicit
rule in front of it, so the behaviour can change with another model, another IQ version or another
wording, and the model could answer from its own knowledge, or make something up, instead of
calling your tool. To reduce the risk:

- Say in the description when to use the tool, questions included: "Use it when the user asks
  ...". The example tools do.
- Test every tool both ways, as a question and as a command (*"What are the support hours?"* /
  *"Show the support hours"*), and repeat the tests after every IQ upgrade or model change.
- Expect more refusals the further a tool is from DX: present it as part of the portal (your
  company, your services, your content) rather than as a general-purpose assistant.
- End what the tool returns with an instruction to use only that information, as the example tools
  do, so the answer comes from your data.

## Build your own server from this skeleton

1. **Write your tool**: a Python function with `@mcp.tool()`. The SDK builds the tool from it:

   ```python
   @mcp.tool()
   def opening_hours(office: str) -> str:
       """Opening hours of one of our offices. Use it when the user asks when an office is open.
       Parameter office: the city of the office."""
       return lookup_hours(office)
   ```

   - The function name is the tool name: only `[a-zA-Z0-9_-]` (required by IQ / Claude).
   - The docstring is the description. It is all the LLM reads to decide when to use the tool, and
     it travels in every request, so keep it short and precise.
   - The type hints are the parameter schema; the returned string is what the LLM receives.
2. **Remove the EUROPESIP tools** you do not need. Keep the `FastMCP(...)` settings, the
   `/probe/ready` route and the request log: they are what the IQ Integrator needs.
3. **Configuration** (URLs, connections) comes from environment variables in the Deployment;
   secrets, from a Kubernetes Secret.
4. **Rebuild the image** (fork this repository and its workflow publishes it to your ghcr.io) and
   update the list of tool names that the CI test checks in
   [.github/workflows/image.yml](.github/workflows/image.yml).
5. **Deploy it and restart the IQ Integrator**, which only lists the tools when it starts (Lab 3B,
   steps 3B-1 to 3B-3).

## Ideas to extend it

- **The FAQ from a database.** Replace the `FAQ` dictionary with a query to PostgreSQL (the labs
  already run one with CloudNativePG) or any other database: the answers are maintained without
  rebuilding the image. Use a read-only user, credentials from a Secret and parameterised queries.
- **The FAQ from DX content.** Read the answers from WCM content through the DX REST APIs, with the
  session of the user asking (like `europesip_whoami`): editors maintain them in DX, and each user
  only gets what they are allowed to see.
- **Your business systems.** Tools that call your CRM, your ticketing system or your ERP: "open a
  support ticket", "what is the status of my order".
- **Your own DX operations, not the generic ones.** The HCL MCP Server already gives IQ more than
  50 tools for the generic DX operations (list libraries and pages, search content and DAM assets,
  create or update WCM content, site areas, projects and pages...): do not duplicate them. A custom
  tool makes sense for operations specific to your organisation, which combine several steps or
  your own rules: for example "publish a news item" with your template, site area, categories and
  approval in one step, or a check of your editorial rules before publishing. Always with the
  permissions of the user asking (like `europesip_whoami`), never with an administrative account.
- **RAG: add knowledge, not only data.** A `search_knowledge(query)` tool that runs a semantic
  search over your documents (manuals, procedures, product sheets) and returns the most relevant
  passages for IQ to answer with. For example: embeddings computed through the LiteLLM that IQ
  already uses, stored in PostgreSQL with pgvector. The RAG of IQ itself is disabled in IQ 1.0.2,
  so an MCP Server is a way to add it now, with your own sources and your own rules.
- **Other HCL products, such as HCL Domino.** Tools that call the Domino REST API to search, read or
  update Domino applications, including the ones that already use AI through HCL Domino IQ: the
  DX IQ chat becomes a single entry point to both platforms.
- **Complex or operational tasks: the chat starts them, a portlet completes them.** Some work needs
  a visual interface that is hard to get in a chat (reviewing a design, adjusting many options,
  approving results) or is long and operational. The MCP tool only creates the task in a database
  shared with a traditional DX portlet, and returns its id and a link; the user then follows,
  adjusts and completes it in the portlet, with a richer interface. For example, `figma_web_to_dx`
  could receive the Figma URL, create the conversion task and leave the review of the generated
  components to the portlet.
- **Several servers.** One MCP Server per domain or team, each with its own release cycle.

## Image

```bash
docker pull ghcr.io/europesip/hcl-dx-iq-europesip-mcp:1.0.1
```

amd64 and arm64, non-root user, port 3000. [GitHub Actions](.github/workflows/image.yml) builds it
on every push, starts it, speaks MCP to it (`initialize`, `tools/list`) and only then publishes it:

| Event | Tags published |
|---|---|
| Push to `main` | `main`, `sha-<commit>` |
| Tag `vX.Y.Z` | `X.Y.Z`, `X.Y`, `latest` |
| Pull request | none (build and test only) |

| Variable | Default | Use |
|---|---|---|
| `PORT` | `3000` | Listening port |
| `DX_URL` | `https://dx-deployment-haproxy.dx-demo.svc.cluster.local` | DX entry point inside the cluster (the DX HAProxy service), for `europesip_whoami` |

## Kubernetes

The labs deploy it with
[europesip-mcp.yaml](https://github.com/europesip/hcl-dx-compose-labs/blob/main/lab3-iq-openrouter/custom-mcp/europesip-mcp.yaml)
(Deployment + Service `europesip-mcp:3000`), and add
`http://europesip-mcp.<namespace>.svc.cluster.local:3000` to the IQ Integrator MCP server list.

> **Support.** HCL documents the MCP server list for its own MCP Server; adding custom servers is
> not documented nor supported in IQ 1.0.2 and needs a workaround (HCL case CS1479102), described
> in the Lab 3 guide.

## Try it locally

```bash
docker run --rm -p 3000:3000 ghcr.io/europesip/hcl-dx-iq-europesip-mcp:1.0.1
```

```bash
curl -s -X POST http://localhost:3000/mcp -H 'Content-Type: application/json' -H 'Accept: application/json, text/event-stream' -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}'
```

## Security

A custom MCP Server is trusted code: it receives the DX session of every user who asks IQ.

- Review what it does, and never log the cookie values (this one only logs their names).
- Protect access to it, for example with a NetworkPolicy so that only the IQ Integrator can call it.
- This example is for a lab: it does not validate the Host header, and `europesip_whoami` does not
  verify the DX certificate (the labs use a self-signed one). Verify it in production.

## Licence

Apache License 2.0, see [LICENSE](LICENSE) and [NOTICE](NOTICE). Copyright 2026 EUROPESIP.
