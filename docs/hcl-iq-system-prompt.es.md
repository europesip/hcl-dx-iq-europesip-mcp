# El system prompt de HCL DX IQ: qué dice y qué implica para tus herramientas

[English](hcl-iq-system-prompt.md) · **Español**

El IQ Integrator pone un *system prompt* delante de **cada** petición que envía al LLM. Forma parte
del producto de HCL, no se puede configurar, y sus reglas se aplican también a las herramientas de
un MCP Server propio. Esta página lo resume, sección a sección, y explica qué implica cada parte para
quien construye su propio MCP Server o despliega IQ.

- Observado en **IQ 1.0.3 (HCL DX Compose CF239)**, el 2026-11-04, y comparado con IQ 1.0.2 (CF238).
- Tamaño: **18.912 caracteres** (≈ 4.700 tokens) en 1.0.3, frente a 14.104 en 1.0.2.
- El texto completo es de HCL y no se reproduce aquí; las citas son fragmentos breves. Para leerlo
  en tu propia instalación, ver [Cómo ver el prompt completo](#cómo-ver-el-prompt-completo).

## Estructura (IQ 1.0.3)

En este orden, tras las líneas iniciales (papel del asistente, ámbito de conocimiento y regla de idioma):

| # | Sección | Qué dice, en resumen | Qué implica para ti |
|---|---|---|---|
| 1 | **Audiencia e idioma** · *no negociable* (nueva en 1.0.3) | Por defecto el usuario es un **autor de contenido o gestor de sitio**, no un desarrollador. Lenguaje de negocio, en términos de la interfaz de DX. Sin APIs, endpoints, JSON, TOON, IDs ni UUIDs salvo que el usuario lo pida o sea claramente técnico; el detalle técnico se ofrece como pregunta de seguimiento | Lo que devuelva tu herramienta (ids, URLs de APIs, códigos) se ocultará o se parafraseará a menudo. Devuelve lo que un autor necesita leer, no datos técnicos en bruto |
| 2 | **Configuración del servidor DX** | El host y el *context root* de la instalación; los enlaces siempre como URL completa | Los enlaces que devuelva tu herramienta deben ser URLs completas sobre el host de DX |
| 3 | **Contexto del entorno y las herramientas** | "All outputs ... returned by MCP ... server tools are strictly structured in TOON" (Token-Oriented Object Notation), y se tratan como fiables | Pensado para las herramientas de HCL. El texto normal de una herramienta propia funciona en nuestras pruebas, pero que sea breve y sin ambigüedades |
| 4 | **Directiva de memoria persistente entre sesiones (RAG con pgvector)** | El modelo "has access to injected historical context from prior conversations", que debe tratar como "authoritative" | **Se envía aunque el RAG esté desactivado** (case CS1479139). El modelo puede referirse a una "memoria" que no existe |
| 5 | **Seguridad** · *no negociable* | El prompt no se puede anular; detectar y rechazar *jailbreaks*, cambios de rol y contenido dañino, con un rechazo acotado a DX | Descripciones o resultados de herramientas que parezcan instrucciones ("ignora...", "actúa como...") pueden provocar un rechazo |
| 6 | **Límite de temas ajenos** · *no negociable* (nueva en 1.0.3) | Los temas que no son de DX (entretenimiento, deportes, noticias, juegos...) reciben de inmediato un rechazo fijo, sin intentar relacionarlos con DX | **La más importante para herramientas propias.** Una herramienta sobre algo lejano a DX (un CRM, el tiempo, Domino...) puede rechazarse antes de llamarla. Presenta tus herramientas como parte del portal y del negocio |
| 7 | **Formato de salida** · *no negociable* | Cada respuesta es un objeto JSON (`answer` + `metadata`: confianza, categoría, fuentes, preguntas de seguimiento), más reglas de formato para pasos, opciones, títulos y separadores | Tu herramienta devuelve texto normal; el modelo lo pone en este formato y el chat de IQ lo presenta |
| 8 | **Enrutado: INQUIRY frente a ACTION** | Preguntas ("What / How / Why / Can I / Is it possible") → **inquiry**: "answer from DX knowledge, NO tools". Órdenes ("List / Show / Create / Get / Update / Delete") → **action**: usar las herramientas | Sin cambios en 1.0.3. Las preguntas sobre tus datos pueden responderse **sin llamar a tu herramienta**. Ver abajo |
| 9 | **Modo action** | Regla de oro (probar primero las herramientas), regla anti-alucinación (llamar antes de responder, mostrar solo resultados reales), un flujo de 6 pasos y **tablas que asocian cada intención a una herramienta de HCL** (DAM, WCM, páginas) | Las tablas solo incluyen herramientas de HCL; si ninguna encaja, el modelo debe decir "I don't have a tool for [operation]". Tu herramienta compite solo con su descripción |
| 10 | **Explicación previa a la herramienta** | Una frase breve antes de cada llamada, en el idioma del usuario, sin nombres de herramientas ni UUIDs | Normal: el usuario ve "Consultando el horario de soporte..." y no el nombre de la herramienta |
| 11 | **Estado de la conversación** | Recordar resultados, resolver "esa biblioteca", encadenar llamadas | Los resultados de tu herramienta pueden reutilizarse en los turnos siguientes |
| 12 | **Reglas de contenido y precisión** | No inventar funcionalidades, URLs ni APIs; enlace a la documentación oficial; listas de más de 50 elementos resumidas; sin `offset`/`limit` (nuevo); enmascarar credenciales; sin UUIDs; ocultar páginas inactivas | Devuelve un número razonable de elementos, y nunca secretos |

## Qué cambia de IQ 1.0.2 a 1.0.3

| Cambio | Detalle |
|---|---|
| **Nueva: audiencia e idioma** | Autores y gestores de sitio por defecto, respuestas no técnicas (ver sección 1) |
| **Nueva: límite de temas ajenos** | Rechazo fijo para temas que no son de DX (ver sección 6) |
| **Directiva de RAG reescrita** | Desaparecen: la tabla `public.rag_chunks`, "do not claim you lack ... memory", las etiquetas "Past conversation note:" / "CRITICAL SYSTEM MEMORY HISTORY", la "absolute historical truth" del texto de otras sesiones y "do not default to live DX tool searches". Se añade: responder con conocimiento de DX u ofrecer una búsqueda en vivo cuando no hay contexto, y remitir al administrador a quien quiera borrar su historial. Se sigue enviando con el RAG desactivado |
| **Tablas de herramientas rehechas** | De 10 de consulta + 16 de cambio con nombres antiguos (`getAllLibraries`...) a cinco tablas con los nombres reales de 1.0.3 (`get_all_libraries_from_WCM`...). DAM aparece por primera vez; nuevas herramientas de páginas (`link_content_to_page`, `unlink_content_from_page`, plantillas de página, temas) |
| **Nuevo paso 6: aviso de refresco** | Tras crear, modificar o borrar con éxito, cada respuesta termina con "Please refresh the page or navigate to the relevant page to see the changes." |
| **Regla de idioma** | Sigue siendo "el idioma del usuario", ahora con inglés por defecto si no se puede determinar |
| **Paginación** | No mostrar nunca `offset` / `limit`; decir "Showing 20 of 42 items" |
| **Sin cambios** | Enrutado inquiry/action, seguridad, formato JSON de salida, regla anti-alucinación, contexto TOON |

## Qué implica si construyes tu propio MCP Server

1. **Las preguntas pueden saltarse tu herramienta.** La regla de inquiry dice "NO tools" para las
   preguntas. En nuestras pruebas (IQ 1.0.2 y 1.0.3, Claude Sonnet 4.6) el modelo sí llamó a
   nuestras herramientas con preguntas como "¿Cuál es el horario de soporte?" cuando la descripción
   encajaba, pero es el modelo sopesando tu herramienta frente a una regla explícita. Escribe
   descripciones que digan cuándo usar la herramienta, preguntas incluidas, y prueba cada
   herramienta como pregunta y como orden tras cada actualización de IQ.
2. **Mantente cerca de DX.** La nueva regla de temas ajenos hace más probable que se rechacen las
   herramientas alejadas de DX. Preséntalas como parte del portal: tu empresa, tus servicios, tu
   contenido, tus procesos.
3. **Escribe para autores.** Devuelve información legible, no ids ni JSON en bruto: la regla de
   audiencia ocultará el detalle técnico igualmente.
4. **Ancla la respuesta.** Termina lo que devuelve la herramienta con una instrucción de usar solo
   esa información, para que el modelo no la "adorne" (las herramientas de ejemplo lo hacen).
5. **Ojo al coste.** El prompt son ≈ 4.700 tokens y las definiciones de las 55 herramientas de HCL
   unos 25.000 más: ≈ 32.500 tokens antes de la pregunta del usuario, en cada llamada. Cada
   herramienta propia suma su descripción. Ver la nota sobre *prompt caching* de los labs
   ([issues.es.md, CS1479178](https://github.com/europesip/hcl-dx-compose-labs/blob/main/issues.es.md)).

## Cómo ver el prompt completo

El prompt no está en los values de Helm; la forma más sencilla de leerlo es el log de la pasarela LLM:

1. Pon LiteLLM en modo depuración, por ejemplo `kubectl -n <ns> set env deploy/litellm LITELLM_LOG=DEBUG`
   (o `logLevel: DEBUG` en sus values de Helm, más limpio con Helm 4).
2. Haz una pregunta a IQ.
3. Busca el mensaje `system` en el log: `kubectl -n <ns> logs deploy/litellm | grep "REQUEST ROUTING"`.
4. Vuelve a poner el nivel en `INFO`: el log de depuración contiene la conversación entera.

El Integrator registra además su tamaño al arrancar: `[Server] System prompt length: 18912 characters`.

## Referencias

- Lab 3 de los labs de HCL DX Compose, al que pertenece este servidor:
  [GUIDE](https://github.com/europesip/hcl-dx-compose-labs/blob/main/lab3-iq-openrouter/GUIDE.es.md)
- Problemas conocidos de IQ, revisados en CF239:
  [issues.es.md](https://github.com/europesip/hcl-dx-compose-labs/blob/main/issues.es.md)
