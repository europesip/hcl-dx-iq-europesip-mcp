# Servidor MCP propio de EUROPESIP para HCL DX IQ

[English](index.md) · **Español**

**Un esqueleto para construir tu propio servidor MCP y ampliar HCL DX IQ con tus propias herramientas.** HCL DX IQ trae
un MCP Server de HCL que da al asistente sus herramientas de DX; IQ también puede llamar a **otros MCP Servers**: tu
propio conocimiento, tus propios sistemas y tus propias acciones, disponibles desde el chat de IQ.

Este repositorio es un ejemplo de eso, no un producto. Es pequeño (un único fichero de Python,
[server.py](https://github.com/europesip/hcl-dx-iq-europesip-mcp/blob/main/server.py), comentado por secciones), funciona tal cual y está pensado para copiarlo:
sustituye las herramientas de EUROPESIP por las tuyas y tendrás la base de tu propio servidor. Es el servidor MCP
propio del **Lab 3B** de los [labs de HCL DX Compose](https://github.com/europesip/hcl-dx-compose-labs). No es
software de HCL.

> Esta página es el resumen para el portal del desarrollador. La guía completa (preguntas de ejemplo, cada paso para
> construir tu propio servidor, ideas para ampliarlo) es el [README en GitHub](https://github.com/europesip/hcl-dx-iq-europesip-mcp/blob/main/README.es.md).

## Cómo lo usa IQ

```
 usuario ──► chat de IQ ──► IQ Integrator ──► LLM              (decide qué herramienta llamar)
                                ├─► MCP Server de HCL          (herramientas de DX)
                                └─► este MCP Server   /mcp     (tus herramientas)
```

1. Al arrancar, el IQ Integrator pide sus herramientas a cada MCP Server de su lista (`tools/list`).
2. En cada pregunta, el LLM lee las descripciones de las herramientas y decide si llama a alguna (`tools/call`).
3. IQ redacta la respuesta con lo que devolvió la herramienta, en el idioma del usuario.

En cada `tools/call` el Integrator reenvía además **las cookies de sesión de DX del usuario que pregunta**, así que una
herramienta puede llamar a DX con la identidad y los permisos de ese usuario.

## Las cinco herramientas de ejemplo

| Herramienta | Qué hace | Patrón que muestra |
|---|---|---|
| `europesip_services()` | Quién es EUROPESIP y qué servicios ofrece | La herramienta más simple: sin parámetros, respuesta fija |
| `europesip_faq(topic)` | Horario de soporte, IA, soberanía digital, laboratorios, contacto... | Un parámetro que rellena el LLM y una consulta a una base de conocimiento (la herramienta a sustituir por tus datos) |
| `figma_web_to_dx(source)`, mostrada como **figma&web-to-dx** | Presenta la herramienta de EUROPESIP que crea componentes de WCM / Blueprint desde Figma, pantallazos o URLs | Un nombre técnico (solo `[a-zA-Z0-9_-]`) distinto del nombre visible |
| `europesip_whoami()` | Quién es el usuario que pregunta, leído de DX | **Llamar a DX como el usuario que pregunta**, con la sesión que reenvía el Integrator |
| `europesip_echo(text)` | Devuelve el texto que recibe | Diagnóstico de todo el camino, sin que el LLM interprete nada |

Las preguntas sobre el propio DX siguen yendo al MCP Server de HCL: los dos servidores trabajan a la vez.

## A tener en cuenta: el system prompt de HCL

Tus herramientas no hablan solas con el LLM: el IQ Integrator pone delante de cada petición el system prompt de HCL, y
sus salvaguardas (guardrails) también afectan a tus herramientas (enrutado de peticiones INQUIRY frente a ACTION, un modo
action escrito pensando en las herramientas de HCL, un asistente acotado a HCL DX, respuestas escritas para autores,
todas las respuestas en JSON). Sección a sección, con los cambios de IQ 1.0.3:
**[El system prompt de HCL DX IQ](hcl-iq-system-prompt.es.md)**.

## Construir tu propio servidor, en resumen

1. **Escribe tu herramienta**: una función de Python con `@mcp.tool()`. El nombre de la función es el nombre de la
   herramienta (solo `[a-zA-Z0-9_-]`), el docstring es la descripción que lee el LLM, las anotaciones de tipo son el
   esquema de los parámetros.
2. **Quita las herramientas de EUROPESIP** que no necesites. Mantén la configuración de `FastMCP(...)`, la ruta
   `/probe/ready` y el log de peticiones: es lo que necesita el IQ Integrator.
3. **La configuración** llega por variables de entorno del Deployment; los secretos, de un Secret de Kubernetes.
4. **Reconstruye la imagen** (haz un fork de este repositorio y su workflow la publica en tu ghcr.io) y actualiza la
   lista de nombres de herramientas que comprueba el test de CI en
   [.github/workflows/image.yml](https://github.com/europesip/hcl-dx-iq-europesip-mcp/blob/main/.github/workflows/image.yml).
5. **Despliégalo y reinicia el IQ Integrator**, que solo lista las herramientas al arrancar (Lab 3B, pasos 3B-1 a
   3B-3).

Paso a paso, con ideas para ampliarlo (la FAQ desde una base de datos o desde contenido de DX, sistemas de negocio,
RAG, HCL Domino...):
[Construir tu propio servidor a partir de este esqueleto](https://github.com/europesip/hcl-dx-iq-europesip-mcp/blob/main/README.es.md#construir-tu-propio-servidor-a-partir-de-este-esqueleto).

## Imagen y despliegue

| | |
|---|---|
| **Imagen** | `ghcr.io/europesip/hcl-dx-iq-europesip-mcp:1.0.2`: amd64 y arm64, usuario no root, puerto 3000. GitHub Actions la construye, la arranca, le habla MCP (`initialize`, `tools/list`) y solo entonces la publica |
| **Variables** | `PORT` (por defecto `3000`); `DX_URL`, la entrada a DX dentro del clúster (el servicio HAProxy de DX), para `europesip_whoami` |
| **Kubernetes** | Los labs lo despliegan con [europesip-mcp.yaml](https://github.com/europesip/hcl-dx-compose-labs/blob/main/lab3-iq-openrouter/custom-mcp/europesip-mcp.yaml) (Deployment + Service `europesip-mcp:3000`) y añaden `http://europesip-mcp.<namespace>.svc.cluster.local:3000` a la lista de servidores MCP del IQ Integrator. Cómo desplegarlo y registrarlo: la [guía del Lab 3](https://github.com/europesip/hcl-dx-compose-labs/blob/main/lab3-iq-openrouter/GUIDE.es.md) |

> **Soporte.** HCL documenta la lista de servidores MCP para su propio MCP Server; añadir servidores propios no está
> documentado ni soportado en IQ 1.0.2 y necesita un workaround (caso de HCL CS1479102), descrito en la guía del Lab 3.

Probarlo en local:

```bash
docker run --rm -p 3000:3000 ghcr.io/europesip/hcl-dx-iq-europesip-mcp:1.0.2
curl -s -X POST http://localhost:3000/mcp -H 'Content-Type: application/json' -H 'Accept: application/json, text/event-stream' -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}'
```

## Seguridad

Un MCP Server propio es código de confianza: recibe la sesión de DX de cada usuario que pregunta a IQ.

- Revisa lo que hace y no registres nunca el valor de las cookies (este solo registra sus nombres).
- Protege el acceso, por ejemplo con una NetworkPolicy para que solo el IQ Integrator pueda llamarlo.
- Este ejemplo es de laboratorio: no valida la cabecera Host, y `europesip_whoami` no verifica el certificado de DX
  (los labs usan uno autofirmado). Verifícalo en producción.

## Más

Código, versiones e imagen: [GitHub](https://github.com/europesip/hcl-dx-iq-europesip-mcp) · [Versiones](https://github.com/europesip/hcl-dx-iq-europesip-mcp/releases) ·
[Paquetes](https://github.com/europesip/hcl-dx-iq-europesip-mcp/pkgs/container/hcl-dx-iq-europesip-mcp).

Licencia: Apache License 2.0, ver [LICENSE](https://github.com/europesip/hcl-dx-iq-europesip-mcp/blob/main/LICENSE) y [NOTICE](https://github.com/europesip/hcl-dx-iq-europesip-mcp/blob/main/NOTICE). Copyright 2026
EUROPESIP. HCL, Digital Experience y otros nombres de productos son marcas de sus respectivos propietarios.
