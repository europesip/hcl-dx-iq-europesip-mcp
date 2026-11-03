# Servidor MCP propio de EUROPESIP para HCL DX IQ

[English](README.md)

El servidor MCP propio del **Lab 3B** de los
[labs de HCL DX Compose](https://github.com/europesip/hcl-dx-compose-labs): un ejemplo de cómo
añadir herramientas propias a HCL DX IQ, junto al MCP Server que trae HCL. No es software de HCL.

Publica cinco herramientas por HTTP "streamable" en `POST /mcp` (sin sesiones, como el MCP Server de HCL):

| Herramienta | Devuelve |
|---|---|
| `europesip_services()` | Quién es EUROPESIP y qué servicios ofrece |
| `europesip_faq(topic)` | Soporte, IA, soberanía digital, laboratorios, contacto... |
| `figma_web_to_dx(source)`, mostrada como **figma&web-to-dx** | Presenta la herramienta de EUROPESIP que crea componentes de WCM / Blueprint desde Figma, pantallazos o URLs |
| `europesip_whoami()` | Quién es el usuario que pregunta a IQ, leído de DX **con la sesión de ese mismo usuario** (el Integrator de IQ reenvía las cookies de DX en cada llamada) |
| `europesip_echo(text)` | Diagnóstico |

Todo el servidor es [server.py](server.py) (unas 190 líneas, SDK oficial de MCP para Python). La
[guía del Lab 3](https://github.com/europesip/hcl-dx-compose-labs/blob/main/lab3-iq-openrouter/GUIDE.es.md)
lo explica y cuenta cómo registrarlo en IQ.

## Imagen

```bash
docker pull ghcr.io/europesip/hcl-dx-iq-europesip-mcp:1.0.0
```

amd64 y arm64, usuario no root, puerto 3000. La construye y la prueba
[GitHub Actions](.github/workflows/image.yml) en cada push; una etiqueta `vX.Y.Z` publica `X.Y.Z`,
`X.Y` y `latest`.

| Variable | Por defecto | Uso |
|---|---|---|
| `PORT` | `3000` | Puerto de escucha |
| `DX_URL` | `https://dx-deployment-haproxy.dx-demo.svc.cluster.local` | Entrada a DX dentro del clúster (el servicio HAProxy de DX), para `europesip_whoami` |

## Kubernetes

Los labs lo despliegan con
[europesip-mcp.yaml](https://github.com/europesip/hcl-dx-compose-labs/blob/main/lab3-iq-openrouter/custom-mcp/europesip-mcp.yaml)
(Deployment + Service `europesip-mcp:3000`) y añaden
`http://europesip-mcp.<namespace>.svc.cluster.local:3000` a la lista de servidores MCP del Integrator de IQ.

## Probarlo en local

```bash
docker run --rm -p 3000:3000 ghcr.io/europesip/hcl-dx-iq-europesip-mcp:1.0.0
```

```bash
curl -s -X POST http://localhost:3000/mcp -H 'Content-Type: application/json' -H 'Accept: application/json, text/event-stream' -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}'
```

## Seguridad

Es un ejemplo de laboratorio: no valida la cabecera Host, y `europesip_whoami` no verifica el
certificado de DX (los labs usan uno autofirmado). Registra los nombres de las cabeceras y cookies
que recibe, nunca sus valores.

## Licencia

Apache License 2.0, ver [LICENSE](LICENSE) y [NOTICE](NOTICE). Copyright 2026 EUROPESIP.
