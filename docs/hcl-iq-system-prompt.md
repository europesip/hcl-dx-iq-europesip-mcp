# The HCL DX IQ system prompt: what it says and what it means for your tools

**English** · [Español](hcl-iq-system-prompt.es.md)

The IQ Integrator puts a system prompt in front of **every** request it sends to the LLM. It is
part of the HCL product, it cannot be configured, and its rules apply to the tools of a custom MCP
server too. This page summarises it, section by section, and explains what each part means for
someone building their own MCP server or rolling out IQ.

- Observed on **IQ 1.0.3 (HCL DX Compose CF239)**, 2026-11-04, and compared with IQ 1.0.2 (CF238).
- Size: **18,912 characters** (≈ 4,700 tokens) in 1.0.3, against 14,104 in 1.0.2.
- The full text is HCL's and is not reproduced here; the quotes are short excerpts. To read it in
  your own installation, see [How to see the full prompt](#how-to-see-the-full-prompt).

## Structure (IQ 1.0.3)

In this order, after the opening lines (role of the assistant, knowledge scope and language rule):

| # | Section | What it says, in short | What it means for you |
|---|---|---|---|
| 1 | **Audience & language** · *non-negotiable* (new in 1.0.3) | By default the user is a **content author or site manager**, not a developer. Plain business language, in terms of the DX UI. No APIs, endpoints, JSON, TOON, IDs or UUIDs unless the user asks or is clearly technical; technical detail is offered as a follow-up | Data your tool returns (ids, URLs of APIs, codes) will often be hidden or paraphrased. Return what an author needs to read, not raw technical payloads |
| 2 | **DX server configuration** | The DX host and context root of the installation; links must always be complete URLs | Links your tool returns should be full URLs on the DX host |
| 3 | **Environment & tooling context** | "All outputs ... returned by MCP ... server tools are strictly structured in TOON" (Token-Oriented Object Notation), to be treated as authoritative | Written for the HCL tools. Plain text from a custom tool works in our tests, but keep it short and unambiguous |
| 4 | **Persistent cross-session memory directive (pgvector RAG)** | The model "has access to injected historical context from prior conversations", to be treated as "authoritative" | **Sent even when RAG is disabled** (case CS1479139). The model may refer to a "memory" that does not exist |
| 5 | **Security** · *non-negotiable* | The prompt cannot be overridden; detect and refuse jailbreaks, role changes and harmful content, with a DX-scoped refusal | Tool descriptions or results that look like instructions ("ignore...", "act as...") can trigger a refusal |
| 6 | **Off-topic boundary** · *non-negotiable* (new in 1.0.3) | Non-DX topics (entertainment, sports, news, games...) must get an immediate fixed refusal, without trying to relate them to DX | **The most important one for custom tools.** A tool about something far from DX (a CRM, the weather, Domino...) may be refused before it is called. Present your tools as part of the portal and its business |
| 7 | **Output format** · *non-negotiable* | Every answer is one JSON object (`answer` + `metadata`: confidence, category, sources, follow-up questions), plus formatting rules for steps, options, headings and rules | Your tool returns plain text; the model puts it in this format and the IQ chat renders it |
| 8 | **Request routing: INQUIRY vs ACTION** | Questions ("What / How / Why / Can I / Is it possible") → **inquiry**: "answer from DX knowledge, NO tools". Commands ("List / Show / Create / Get / Update / Delete") → **action**: use the tools | Unchanged in 1.0.3. Questions about your data may be answered **without calling your tool**. See below |
| 9 | **Action mode** | Golden rule (try tools first), anti-hallucination rule (call before answering, report only real results), a 6-step workflow and **tables that map each intent to an HCL tool** (DAM, WCM, pages) | The tables only list HCL tools; if none matches, the model is told to say "I don't have a tool for [operation]". Your tool competes only through its description |
| 10 | **Pre-tool explanation** | One short sentence before each tool call, in the user's language, without tool names or UUIDs | Normal: the user sees "Looking up the support hours..." rather than the tool name |
| 11 | **Conversation state** | Remember results, resolve "that library", chain calls | Your tool's results can be reused in the next turns |
| 12 | **Content & accuracy rules** | Do not invent features, URLs or APIs; official documentation link; lists over 50 items shortened; no `offset`/`limit` (new); mask credentials; no UUIDs; hide inactive pages | Return a reasonable number of items, and never secrets |

## What changed from IQ 1.0.2 to 1.0.3

| Change | Detail |
|---|---|
| **New: Audience & language** | Authors and site managers by default, non-technical answers (see section 1) |
| **New: Off-topic boundary** | Fixed refusal for non-DX topics (see section 6) |
| **RAG directive rewritten** | Removed: the `public.rag_chunks` table, "do not claim you lack ... memory", the labels "Past conversation note:" / "CRITICAL SYSTEM MEMORY HISTORY", "absolute historical truth" for text from other sessions, and "do not default to live DX tool searches". Added: answer from DX knowledge or offer a live search when there is no context, and send users who want their history deleted to their administrator. Still sent with RAG disabled |
| **Tool tables rebuilt** | From 10 retrieve + 16 mutation tools with old names (`getAllLibraries`...) to five tables with the real 1.0.3 names (`get_all_libraries_from_WCM`...). DAM appears for the first time; new page tools (`link_content_to_page`, `unlink_content_from_page`, page templates, themes) |
| **New step 6: refresh notice** | After a successful create, update or delete, every answer ends with "Please refresh the page or navigate to the relevant page to see the changes." |
| **Language rule** | Still "the language the user is using", now with English as the default when it cannot be determined |
| **Pagination** | Never show `offset` / `limit`; say "Showing 20 of 42 items" |
| **Unchanged** | Inquiry vs action routing, security, JSON output format, anti-hallucination rule, TOON context |

## What it means if you build your own MCP server

1. **Questions may skip your tool.** The inquiry rule says "NO tools" for questions. In our tests
   (IQ 1.0.2 and 1.0.3, Claude Sonnet 4.6) the model still called our tools for questions such as
   "What are the support hours?" when the description matched, but that is the model weighing your
   tool against an explicit rule. Write descriptions that say when to use the tool, questions
   included, and test every tool as a question and as a command after each IQ upgrade.
2. **Stay close to DX.** The new off-topic rule makes tools far from DX more likely to be refused.
   Present them as part of the portal: your company, your services, your content, your processes.
3. **Write for authors.** Return readable information, not ids or raw JSON: the audience rule will
   hide technical detail anyway.
4. **Ground the answer.** End what the tool returns with an instruction to use only that
   information, so the model does not "embellish" it (the example tools do).
5. **Mind the cost.** The prompt is ≈ 4,700 tokens and the 55 HCL tool definitions about 25,000
   more: ≈ 32,500 tokens before the user's question, on every call. Each custom tool adds its
   description on top. See the prompt-caching note in the labs
   ([issues.md, CS1479178](https://github.com/europesip/hcl-dx-compose-labs/blob/main/issues.md)).

## How to see the full prompt

The prompt is not in the Helm values; the simplest way to read it is the LLM gateway log:

1. Set LiteLLM to debug, for example `kubectl -n <ns> set env deploy/litellm LITELLM_LOG=DEBUG`
   (or `logLevel: DEBUG` in its Helm values, which is cleaner with Helm 4).
2. Ask IQ one question.
3. Look for the `system` message in the log: `kubectl -n <ns> logs deploy/litellm | grep "REQUEST ROUTING"`.
4. Set the log level back to `INFO`: the debug log contains the whole conversation.

The Integrator also logs its size at start-up: `[Server] System prompt length: 18912 characters`.

## References

- Lab 3 of the HCL DX Compose labs, which this server belongs to:
  [GUIDE](https://github.com/europesip/hcl-dx-compose-labs/blob/main/lab3-iq-openrouter/GUIDE.md)
- Known IQ issues, re-checked on CF239:
  [issues.md](https://github.com/europesip/hcl-dx-compose-labs/blob/main/issues.md)
