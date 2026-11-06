# Servidor MCP propio de EUROPESIP para HCL DX IQ

[English](README.md)

**Un esqueleto para construir tu propio servidor MCP y ampliar HCL DX IQ con tus propias herramientas.**

HCL DX IQ trae un MCP Server de HCL que da al asistente sus herramientas de DX. IQ también puede
llamar a **otros MCP Servers**, y ahí están sus verdaderas posibilidades: tu propio conocimiento,
tus propios sistemas y tus propias acciones, disponibles desde el chat de IQ.

Este repositorio es un ejemplo de eso, no un producto. Es pequeño (un único fichero de Python,
[server.py](server.py), comentado por secciones), funciona tal cual y está pensado para copiarlo:
sustituye las herramientas de EUROPESIP por las tuyas y tendrás la base de tu propio servidor. Es
el servidor MCP propio del **Lab 3B** de los
[labs de HCL DX Compose](https://github.com/europesip/hcl-dx-compose-labs), cuya
[guía del Lab 3](https://github.com/europesip/hcl-dx-compose-labs/blob/main/lab3-iq-openrouter/GUIDE.es.md)
explica cómo desplegarlo y registrarlo en IQ. No es software de HCL.

## Cómo lo usa IQ

```
 usuario ──► chat de IQ ──► IQ Integrator ──► LLM              (decide qué herramienta llamar)
                                ├─► MCP Server de HCL          (herramientas de DX)
                                └─► este MCP Server   /mcp     (tus herramientas)
```

1. Al arrancar, el IQ Integrator pide sus herramientas a cada MCP Server de su lista (`tools/list`).
2. En cada pregunta, el LLM lee las descripciones de las herramientas y decide si llama a alguna
   (`tools/call`).
3. IQ redacta la respuesta con lo que devolvió la herramienta, en el idioma del usuario.

En cada `tools/call` el Integrator reenvía además **las cookies de sesión de DX del usuario que
pregunta**, así que una herramienta puede llamar a DX con la identidad y los permisos de ese usuario.

## Las cinco herramientas de ejemplo

Cada una muestra un patrón distinto:

| Herramienta | Qué hace | Patrón que muestra |
|---|---|---|
| `europesip_services()` | Quién es EUROPESIP y qué servicios ofrece | La herramienta más simple: sin parámetros, respuesta fija |
| `europesip_faq(topic)` | Horario de soporte, IA, soberanía digital, laboratorios, contacto... | Un parámetro que rellena el LLM y una consulta a una base de conocimiento (la herramienta a sustituir por tus datos) |
| `figma_web_to_dx(source)`, mostrada como **figma&web-to-dx** | Presenta la herramienta de EUROPESIP que crea componentes de WCM / Blueprint desde Figma, pantallazos o URLs | Un nombre técnico (solo `[a-zA-Z0-9_-]`) distinto del nombre visible |
| `europesip_whoami()` | Quién es el usuario que pregunta, leído de DX | **Llamar a DX como el usuario que pregunta**, con la sesión que reenvía el Integrator |
| `europesip_echo(text)` | Devuelve el texto que recibe | Diagnóstico de todo el camino, sin que el LLM interprete nada |

Cada respuesta termina con una breve instrucción para que el modelo use solo esa información: sin
ella, el modelo tiende a "adornar" los datos de empresa.

## Preguntas de ejemplo

Lánzalas en el chat de IQ, en español o en inglés (IQ traduce las respuestas):

| Pregunta | Herramienta que llama IQ |
|---|---|
| ¿Quién es EUROPESIP y qué servicios ofrece? | `europesip_services` |
| ¿Cuál es el horario de soporte de EUROPESIP? | `europesip_faq` (tema `support`) |
| ¿Qué opina EUROPESIP sobre la soberanía digital? | `europesip_faq` (tema `sovereignty`) |
| ¿Dónde están los laboratorios de EUROPESIP para instalar DX Compose? | `europesip_faq` (tema `labs`) |
| ¿Cómo contacto con EUROPESIP? | `europesip_faq` (tema `contact`) |
| Quiero crear un componente Blueprint a partir de este diseño de Figma: https://www.figma.com/design/... | `figma_web_to_dx` |
| ¿Quién soy? / ¿Con qué usuario he entrado? | `europesip_whoami` |
| Prueba el eco de EUROPESIP con "hola" | `europesip_echo` |

Las preguntas sobre el propio DX ("¿Qué bibliotecas de WCM hay?") siguen yendo al MCP Server de
HCL: los dos servidores funcionan a la vez.

## A tener en cuenta: el system prompt de HCL

Tus herramientas no hablan solas con el LLM. El IQ Integrator pone delante de cada petición el
system prompt de HCL (unos 4.700 tokens en IQ 1.0.3, 3.600 en 1.0.2; se puede leer en el log de
LiteLLM), y sus salvaguardas (guardrails) también afectan a tus herramientas.
**[El system prompt de HCL DX IQ](docs/hcl-iq-system-prompt.es.md)** lo resume sección a sección,
con los cambios de IQ 1.0.3 y lo que implica cada uno para tus herramientas. Las principales:

- **Enrutado de peticiones: INQUIRY frente a ACTION.** El modelo debe clasificar cada petición. Las
  preguntas ("What / How / Why / Can I / Is it possible...") son *inquiry*: "answer from DX
  knowledge, NO tools". Las órdenes ("List / Show / Create / Get / Update / Delete...") son
  *action*: usar las herramientas sobre el sistema real.
- **El modo action está escrito pensando en las herramientas de HCL.** Asocia cada intención a una
  herramienta de HCL y, si ninguna encaja, indica al modelo que responda "I don't have a tool for
  [operation]".
- **El asistente está acotado a HCL DX.** Su identidad es la de un asistente de DX y no debe
  inventar funcionalidades. Desde IQ 1.0.3 una **regla de temas ajenos** ("no negociable") le hace
  rechazar de inmediato, con una respuesta fija, los temas que no son de DX.
- **Las respuestas se escriben para autores** (desde IQ 1.0.3). Por defecto el usuario es un autor
  de contenido o gestor de sitio: sin APIs, JSON, IDs ni UUIDs salvo que los pida. Los datos
  técnicos que devuelva tu herramienta se ocultarán o se parafrasearán a menudo.
- **Todas las respuestas son JSON** (`answer` más `metadata`), que el chat de IQ presenta. Tu
  herramienta devuelve texto normal; el modelo lo pone en ese formato.

En nuestras pruebas (IQ 1.0.2 y 1.0.3), las preguntas de tipo inquiry de la tabla anterior (*"¿Quién es
EUROPESIP...?"*, *"¿Cuál es el horario de soporte?"*) sí llamaron a las herramientas propias: el
modelo da prioridad a una herramienta cuya descripción encaja con la pregunta. Pero es el modelo
sopesando tu herramienta frente a una regla explícita que tiene delante, así que el comportamiento
puede cambiar con otro modelo, otra versión de IQ u otra forma de preguntar, y el modelo podría
responder con su propio conocimiento, o inventarse algo, en lugar de llamar a tu herramienta. Para
reducir el riesgo:

- Indica en la descripción cuándo usar la herramienta, preguntas incluidas: "Use it when the user
  asks ...". Las herramientas de ejemplo lo hacen.
- Prueba cada herramienta de las dos formas, como pregunta y como orden (*"¿Cuál es el horario de
  soporte?"* / *"Muestra el horario de soporte"*), y repite las pruebas tras cada actualización de
  IQ o cambio de modelo.
- Cuenta con más rechazos cuanto más lejos de DX esté una herramienta: preséntala como parte del
  portal (tu empresa, tus servicios, tu contenido) y no como un asistente de propósito general.
- Termina lo que devuelve la herramienta con una instrucción de usar solo esa información, como
  hacen las herramientas de ejemplo, para que la respuesta salga de tus datos.

## Construir tu propio servidor a partir de este esqueleto

1. **Escribe tu herramienta**: una función de Python con `@mcp.tool()`. El SDK construye la
   herramienta a partir de ella:

   ```python
   @mcp.tool()
   def opening_hours(office: str) -> str:
       """Opening hours of one of our offices. Use it when the user asks when an office is open.
       Parameter office: the city of the office."""
       return lookup_hours(office)
   ```

   - El nombre de la función es el nombre de la herramienta: solo `[a-zA-Z0-9_-]` (lo exigen IQ y Claude).
   - El docstring es la descripción. Es lo único que lee el LLM para decidir cuándo usarla, y viaja
     en cada petición, así que corta y precisa.
   - Las anotaciones de tipo son el esquema de los parámetros; el texto que devuelve es lo que
     recibe el LLM.
2. **Quita las herramientas de EUROPESIP** que no necesites. Mantén la configuración de
   `FastMCP(...)`, la ruta `/probe/ready` y el log de peticiones: es lo que necesita el IQ Integrator.
3. **La configuración** (URLs, conexiones) llega por variables de entorno del Deployment; los
   secretos, de un Secret de Kubernetes.
4. **Reconstruye la imagen** (haz un fork de este repositorio y su workflow la publica en tu
   ghcr.io) y actualiza la lista de nombres de herramientas que comprueba el test de CI en
   [.github/workflows/image.yml](.github/workflows/image.yml).
5. **Despliégalo y reinicia el IQ Integrator**, que solo lista las herramientas al arrancar (Lab 3B,
   pasos 3B-1 a 3B-3).

## Ideas para ampliarlo

- **La FAQ desde una base de datos.** Sustituye el diccionario `FAQ` por una consulta a PostgreSQL
  (los labs ya tienen uno con CloudNativePG) o a cualquier otra base de datos: las respuestas se
  mantienen sin reconstruir la imagen. Usa un usuario de solo lectura, credenciales desde un Secret
  y consultas parametrizadas.
- **La FAQ desde contenido de DX.** Lee las respuestas de contenido de WCM con las APIs REST de DX,
  con la sesión del usuario que pregunta (como `europesip_whoami`): los editores las mantienen en
  DX, y cada usuario solo recibe lo que tiene permitido ver.
- **Tus sistemas de negocio.** Herramientas que llamen a tu CRM, a tu sistema de tickets o a tu
  ERP: "abre un ticket de soporte", "en qué estado está mi pedido".
- **Operaciones de DX propias, no las genéricas.** El MCP Server de HCL ya le da a IQ más de 50
  herramientas para las operaciones genéricas de DX (listar bibliotecas y páginas, buscar contenido
  y activos de DAM, crear o actualizar contenido de WCM, áreas de sitio, proyectos y páginas...): no
  las dupliques. Una herramienta propia tiene sentido para operaciones específicas de tu
  organización, que combinan varios pasos o tus propias reglas: por ejemplo "publicar una noticia"
  con tu plantilla, área de sitio, categorías y aprobación en un solo paso, o comprobar tus normas
  editoriales antes de publicar. Siempre con los permisos del usuario que pregunta (como
  `europesip_whoami`), nunca con una cuenta administrativa.
- **RAG: añadir conocimiento, no solo datos.** Una herramienta `search_knowledge(query)` que haga
  una búsqueda semántica en tus documentos (manuales, procedimientos, fichas de producto) y
  devuelva los fragmentos más relevantes para que IQ responda con ellos. Por ejemplo: embeddings
  calculados a través del LiteLLM que IQ ya usa, guardados en PostgreSQL con pgvector. El RAG del
  propio IQ está deshabilitado en IQ 1.0.2, así que un MCP Server es una forma de añadirlo ya, con
  tus propias fuentes y tus propias reglas.
- **Otros productos de HCL, como HCL Domino.** Herramientas que llamen a la Domino REST API para
  buscar, leer o actualizar aplicaciones de Domino, incluidas las que ya usan IA con HCL Domino IQ:
  el chat de DX IQ se convierte en un punto de entrada único a las dos plataformas.
- **Tareas complejas u operativas: el chat las inicia, un portlet las completa.** Hay trabajos que
  necesitan una interfaz visual difícil de conseguir en un chat (revisar un diseño, ajustar muchas
  opciones, aprobar resultados) o que son largos y operativos. La herramienta MCP solo crea la tarea
  en una base de datos compartida con un portlet tradicional de DX, y devuelve su identificador y
  un enlace; el usuario la sigue, la ajusta y la completa desde el portlet, con una interfaz más
  rica. Por ejemplo, `figma_web_to_dx` podría recibir la URL de Figma, crear la tarea de conversión
  y dejar al portlet la revisión de los componentes generados.
- **Varios servidores.** Un MCP Server por dominio o por equipo, cada uno con su propio ciclo de
  versiones.

## Imagen

```bash
docker pull ghcr.io/europesip/hcl-dx-iq-europesip-mcp:1.0.2
```

amd64 y arm64, usuario no root, puerto 3000. [GitHub Actions](.github/workflows/image.yml) la
construye en cada push, la arranca, le habla MCP (`initialize`, `tools/list`) y solo entonces la
publica:

| Evento | Etiquetas publicadas |
|---|---|
| Push a `main` | `main`, `sha-<commit>` |
| Etiqueta `vX.Y.Z` | `X.Y.Z`, `X.Y`, `latest` |
| Pull request | ninguna (solo construye y prueba) |

| Variable | Por defecto | Uso |
|---|---|---|
| `PORT` | `3000` | Puerto de escucha |
| `DX_URL` | `https://dx-deployment-haproxy.dx-demo.svc.cluster.local` | Entrada a DX dentro del clúster (el servicio HAProxy de DX), para `europesip_whoami` |

## Kubernetes

Los labs lo despliegan con
[europesip-mcp.yaml](https://github.com/europesip/hcl-dx-compose-labs/blob/main/lab3-iq-openrouter/custom-mcp/europesip-mcp.yaml)
(Deployment + Service `europesip-mcp:3000`) y añaden
`http://europesip-mcp.<namespace>.svc.cluster.local:3000` a la lista de servidores MCP del IQ Integrator.

> **Soporte.** HCL documenta la lista de servidores MCP para su propio MCP Server; añadir
> servidores propios no está documentado ni soportado en IQ 1.0.2 y necesita un workaround (caso de
> HCL CS1479102), descrito en la guía del Lab 3.

## Probarlo en local

```bash
docker run --rm -p 3000:3000 ghcr.io/europesip/hcl-dx-iq-europesip-mcp:1.0.2
```

```bash
curl -s -X POST http://localhost:3000/mcp -H 'Content-Type: application/json' -H 'Accept: application/json, text/event-stream' -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}'
```

## Seguridad

Un MCP Server propio es código de confianza: recibe la sesión de DX de cada usuario que pregunta a IQ.

- Revisa lo que hace y no registres nunca el valor de las cookies (este solo registra sus nombres).
- Protege el acceso, por ejemplo con una NetworkPolicy para que solo el IQ Integrator pueda llamarlo.
- Este ejemplo es de laboratorio: no valida la cabecera Host, y `europesip_whoami` no verifica el
  certificado de DX (los labs usan uno autofirmado). Verifícalo en producción.

## Licencia

Apache License 2.0, ver [LICENSE](LICENSE) y [NOTICE](NOTICE). Copyright 2026 EUROPESIP.
