# EUROPESIP custom MCP Server for HCL DX IQ

**English** · [Español](index.es.md)

**A skeleton to build your own MCP Server and extend HCL DX IQ with your own tools.** HCL DX IQ comes with an MCP
Server from HCL that gives the assistant its DX tools; IQ can also call **other MCP Servers**: your own knowledge, your
own systems and your own actions, available from the IQ chat.

This repository is an example of that, not a product. It is small (one Python file,
[server.py](https://github.com/europesip/hcl-dx-iq-europesip-mcp/blob/main/server.py), commented section by section), works as is, and is meant to be copied: replace
the EUROPESIP tools with yours and you have the base of your own server. It is the custom MCP Server of **Lab 3B** of
the [HCL DX Compose labs](https://github.com/europesip/hcl-dx-compose-labs). It is not HCL software.

> This page is the summary for the developer portal. The full guide (example questions, every step to build your own
> server, ideas to extend it) is the [README on GitHub](https://github.com/europesip/hcl-dx-iq-europesip-mcp#readme).

## How IQ uses it

```
 user ──► IQ chat ──► IQ Integrator ──► LLM                (decides which tool to call)
                          ├─► HCL MCP Server               (DX tools)
                          └─► this MCP Server   /mcp       (your tools)
```

1. When the IQ Integrator starts, it asks every MCP Server in its list for its tools (`tools/list`).
2. On every question, the LLM reads the tool descriptions and decides whether to call one (`tools/call`).
3. IQ writes the answer with what the tool returned, in the user's language.

On every `tools/call` the Integrator also forwards **the DX session cookies of the user asking**, so a tool can call
DX with that user's identity and permissions.

## The five example tools

| Tool | What it does | Pattern it shows |
|---|---|---|
| `europesip_services()` | Who EUROPESIP is and which services it offers | The simplest tool: no parameters, a fixed answer |
| `europesip_faq(topic)` | Support hours, AI, digital sovereignty, labs, contact... | A parameter filled in by the LLM, and a knowledge-base lookup (the tool to replace with your own data) |
| `figma_web_to_dx(source)`, shown as **figma&web-to-dx** | Presents the EUROPESIP tool that builds WCM / Blueprint components from Figma, screenshots or URLs | A technical name (`[a-zA-Z0-9_-]` only) different from the display name |
| `europesip_whoami()` | Who the user asking is, read from DX | **Calling DX as the user asking**, with the session forwarded by the Integrator |
| `europesip_echo(text)` | Returns the text it receives | Diagnostics of the whole path, without the LLM interpreting anything |

Questions about DX itself still go to the HCL MCP Server: both servers work side by side.

## Keep in mind: the HCL system prompt

Your tools do not talk to the LLM on their own: the IQ Integrator puts the HCL system prompt in front of every request,
and its guardrails apply to your tools too (inquiry vs action routing, an action mode written around the HCL tools, an
assistant scoped to HCL DX, answers written for authors, every answer in JSON). Section by section, with the changes in
IQ 1.0.3: **[The HCL DX IQ system prompt](hcl-iq-system-prompt.md)**.

## Build your own server, in short

1. **Write your tool**: a Python function with `@mcp.tool()`. The function name is the tool name (only
   `[a-zA-Z0-9_-]`), the docstring is the description the LLM reads, the type hints are the parameter schema.
2. **Remove the EUROPESIP tools** you do not need. Keep the `FastMCP(...)` settings, the `/probe/ready` route and
   the request log: they are what the IQ Integrator needs.
3. **Configuration** comes from environment variables in the Deployment; secrets, from a Kubernetes Secret.
4. **Rebuild the image** (fork this repository and its workflow publishes it to your ghcr.io) and update the list of
   tool names that the CI test checks in [.github/workflows/image.yml](https://github.com/europesip/hcl-dx-iq-europesip-mcp/blob/main/.github/workflows/image.yml).
5. **Deploy it and restart the IQ Integrator**, which only lists the tools when it starts (Lab 3B, steps 3B-1 to 3B-3).

Step by step, with ideas to extend it (FAQ from a database or DX content, business systems, RAG, HCL Domino...):
[Build your own server from this skeleton](https://github.com/europesip/hcl-dx-iq-europesip-mcp#build-your-own-server-from-this-skeleton).

## Image and deployment

| | |
|---|---|
| **Image** | `ghcr.io/europesip/hcl-dx-iq-europesip-mcp:1.0.2`: amd64 and arm64, non-root user, port 3000. GitHub Actions builds it, starts it, speaks MCP to it (`initialize`, `tools/list`) and only then publishes it |
| **Variables** | `PORT` (default `3000`); `DX_URL`, the DX entry point inside the cluster (the DX HAProxy service), for `europesip_whoami` |
| **Kubernetes** | The labs deploy it with [europesip-mcp.yaml](https://github.com/europesip/hcl-dx-compose-labs/blob/main/lab3-iq-openrouter/custom-mcp/europesip-mcp.yaml) (Deployment + Service `europesip-mcp:3000`) and add `http://europesip-mcp.<namespace>.svc.cluster.local:3000` to the IQ Integrator MCP server list. How to deploy and register it: the [Lab 3 guide](https://github.com/europesip/hcl-dx-compose-labs/blob/main/lab3-iq-openrouter/GUIDE.md) |

> **Support.** HCL documents the MCP server list for its own MCP Server; adding custom servers is not documented nor
> supported in IQ 1.0.2 and needs a workaround (HCL case CS1479102), described in the Lab 3 guide.

Try it locally:

```bash
docker run --rm -p 3000:3000 ghcr.io/europesip/hcl-dx-iq-europesip-mcp:1.0.2
curl -s -X POST http://localhost:3000/mcp -H 'Content-Type: application/json' -H 'Accept: application/json, text/event-stream' -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}'
```

## Security

A custom MCP Server is trusted code: it receives the DX session of every user who asks IQ.

- Review what it does, and never log the cookie values (this one only logs their names).
- Protect access to it, for example with a NetworkPolicy so that only the IQ Integrator can call it.
- This example is for a lab: it does not validate the Host header, and `europesip_whoami` does not verify the DX
  certificate (the labs use a self-signed one). Verify it in production.

## More

Source, releases and image: [GitHub](https://github.com/europesip/hcl-dx-iq-europesip-mcp) · [Releases](https://github.com/europesip/hcl-dx-iq-europesip-mcp/releases) ·
[Packages](https://github.com/europesip/hcl-dx-iq-europesip-mcp/pkgs/container/hcl-dx-iq-europesip-mcp).

Licence: Apache License 2.0, see [LICENSE](https://github.com/europesip/hcl-dx-iq-europesip-mcp/blob/main/LICENSE) and [NOTICE](https://github.com/europesip/hcl-dx-iq-europesip-mcp/blob/main/NOTICE). Copyright 2026
EUROPESIP. HCL, Digital Experience and other product names are trademarks of their respective owners.
