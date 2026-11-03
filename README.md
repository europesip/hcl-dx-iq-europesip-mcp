# EUROPESIP custom MCP Server for HCL DX IQ

[Español](README.es.md)

The custom MCP Server of **Lab 3B** of the
[HCL DX Compose labs](https://github.com/europesip/hcl-dx-compose-labs): an example of how to add
your own tools to HCL DX IQ, next to the MCP Server that HCL supplies. It is not HCL software.

It publishes five tools over "streamable" HTTP at `POST /mcp` (stateless, like the HCL MCP Server):

| Tool | Returns |
|---|---|
| `europesip_services()` | Who EUROPESIP is and which services it offers |
| `europesip_faq(topic)` | Support, AI, digital sovereignty, labs, contact... |
| `figma_web_to_dx(source)`, shown as **figma&web-to-dx** | Presents the EUROPESIP tool that builds WCM / Blueprint components from Figma, screenshots or URLs |
| `europesip_whoami()` | Who the user asking IQ is, read from DX **with that user's own session** (the IQ Integrator forwards the DX cookies on every call) |
| `europesip_echo(text)` | Diagnostics |

The whole server is [server.py](server.py) (about 190 lines, official MCP SDK for Python). The
[Lab 3 guide](https://github.com/europesip/hcl-dx-compose-labs/blob/main/lab3-iq-openrouter/GUIDE.md)
explains it and how to register it in IQ.

## Image

```bash
docker pull ghcr.io/europesip/hcl-dx-iq-europesip-mcp:1.0.0
```

amd64 and arm64, non-root user, port 3000. Built and tested by
[GitHub Actions](.github/workflows/image.yml) on every push; a `vX.Y.Z` tag publishes `X.Y.Z`,
`X.Y` and `latest`.

| Variable | Default | Use |
|---|---|---|
| `PORT` | `3000` | Listening port |
| `DX_URL` | `https://dx-deployment-haproxy.dx-demo.svc.cluster.local` | DX entry point inside the cluster (the DX HAProxy service), for `europesip_whoami` |

## Kubernetes

The labs deploy it with
[europesip-mcp.yaml](https://github.com/europesip/hcl-dx-compose-labs/blob/main/lab3-iq-openrouter/custom-mcp/europesip-mcp.yaml)
(Deployment + Service `europesip-mcp:3000`), and add
`http://europesip-mcp.<namespace>.svc.cluster.local:3000` to the IQ Integrator MCP server list.

## Try it locally

```bash
docker run --rm -p 3000:3000 ghcr.io/europesip/hcl-dx-iq-europesip-mcp:1.0.0
```

```bash
curl -s -X POST http://localhost:3000/mcp -H 'Content-Type: application/json' -H 'Accept: application/json, text/event-stream' -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}'
```

## Security

This is a lab example: it does not validate the Host header, and `europesip_whoami` does not
verify the certificate of DX (the labs use a self-signed one). It logs the names of the headers and
cookies it receives, never their values.

## Licence

Apache License 2.0, see [LICENSE](LICENSE) and [NOTICE](NOTICE). Copyright 2026 EUROPESIP.
