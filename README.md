# Criadero de Ámbar

MVP de un juego incremental de cría y coleccionismo de dinosaurios hecho con **LÖVE 11.5** y **LuaJIT**. Incuba huevos, cría adultos, cruza ejemplares, completa el Dinodex y haz la Gran Migración para empezar de nuevo conservando lo permanente.

## Requisitos

- [LÖVE 11.5](https://love2d.org/) para jugar.
- `luajit` para ejecutar los tests fuera del motor.
- Todo el arte del juego se dibuja con `love.graphics`. La interfaz usa **Pixelify Sans** (SIL OFL), incluida en `assets/fonts`.

## Ejecutar

Desde la raíz del proyecto:

```bash
love .
```

La primera vez aparece una guía rápida. El guardado se crea en el directorio de guardado de LÖVE (`save.json` dentro de la carpeta de la aplicación).

## Tests

```bash
luajit tests/run.lua
```

Los tests cubren:

- 100.000 tiradas de rareza frente a `config.rates`.
- Garantías de raro, legendario y mutación sin superar sus umbrales.
- Herencia mendeliana 25/50/25 y fenotipo 75 % dominante.
- Coincidencia entre el simulador de cruces y una simulación real de 200.000 hijos.
- Serialización JSON idempotente, migración y conservación de Dinodex/pity/registro en el prestigio.
- Determinismo: misma semilla y mismas acciones producen el mismo estado.
- Flujo de cruces, prioridad del huevo de cruce, liberación y hitos del Dinodex.

## Controles

| Entrada | Acción |
|---|---|
| Clic | Botones, huevos, tarjetas y pestañas |
| `1`–`7` | Nido, Criadero, Cruces, Mejoras, Dinodex, Registro, Ajustes |
| Rueda | Desplazar listas y rejillas |
| `Esc` | Cerrar paneles; en una apertura, saltar la animación |
| `Espacio` | Saltar la animación de apertura |
| `F5` | Guardar ahora |

## Estructura

```
main.lua                 arranque, canvas, escala, guardado y entrada
conf.lua                 ventana 1280×720, redimensionable y audio activado
assets/fonts/            Pixelify Sans y su licencia OFL
lib/json.lua             JSON propio y determinista
src/audio/audio.lua      música y efectos procedurales (sin archivos externos)
src/game/                lógica pura, sin love.*
  config.lua             única fuente de verdad de tasas, tiempos y costes
  rng.lua                mulberry32 con semilla y contador
  genetics.lua           alelos, fenotipo, herencia y simulador
  hatch.lua              rareza, pity suave, mutaciones y probabilidades
  economy.lua            producción, nido, incubación y mejoras
  prestige.lua           Gran Migración
  state.lua              estado y acciones
  save.lua               serialización, versión y migraciones
src/render/dino.lua      dinosaurios, huevos y mutaciones
src/render/dino_sprites.lua  plantillas pixel-art de 96×56
src/ui/                  tema, widgets, escenas y modales
src/ui/egg_reveal.lua    animación de grietas, rotura y salida del dinosaurio
tests/                   runner y suites con luajit
```

## Interfaz

La pantalla sigue el lenguaje de la referencia: fondo morado con trama de píxeles, tablero de madera, catálogo a la izquierda, mejoras rápidas y prestigio a la derecha, fuente pixel-art y paneles con bisel. Los atajos 1–7 se muestran siempre en el catálogo y los botones tienen respuesta al pulsarlos. El teléfono, los tickets y el tablero están dibujados por código. En el Nido, el área central es una pradera animada: césped que se mece, nubes, valla y hasta seis dinosaurios caminando de lado a lado. Al hacer clic en uno se abre su ficha en el Criadero; los huevos están debajo y las incubadoras en la columna derecha. El Criadero muestra la rejilla y la ficha; el Cruces enfrenta el simulador y la lista de adultos.

## Audio

Todo el sonido se genera al arrancar con `love.sound` y `love.audio`, sin archivos de audio externos:

- **Música**: un bucle lento de 8 compases en Do mayor, a 72 BPM, con pad cálido, bajo suave, melodía de piano con eco y percusión apenas audible. Se reproduce en bucle y baja de volumen durante la eclosión.
- **Efectos**: crujidos progresivos de cáscara, rotura y un acorde ascendente al salir el dinosaurio. El tono del acorde sube ligeramente con la rareza.
- **Ajustes**: **Música** y **Efectos de sonido** se pueden silenciar por separado desde Ajustes. La elección se guarda en la partida y se conserva al migrar.
- Si no hay dispositivo de audio, el juego sigue arrancando sin sonido.

## Dinosaurios

Los dinosaurios son sprites de píxel de **96×56** construidos sobre siluetas anatómicas: cuerpo horizontal, cuello, cola y patas proporcionados, contorno oscuro de un píxel, panza clara y una sombra de píxel. Cada especie tiene su rasgo distintivo: gola y tres cuernos del Triceratops, placas y púas del Stegosaurus, coraza y maza del Ankylosaurus, cresta tubular y pico de pato del Parasaurolophus, plumas y garra del Velociraptor, y alas, cresta y pico del Pteranodon. Las plantillas viven en `src/render/dino_sprites.lua`; los genes de patrón, color, cresta y mutación se aplican encima y la pradera los mueve y los gira. Las siluetas anatómicas de base proceden de PhyloPic (CC0) y se han pixelado y coloreado para el juego.

## Cómo se juega

1. El nido genera huevos automáticamente. Haz clic en un huevo para incubarlo.
2. Cuando termina la incubación, pulsa **ABRIR HUEVOS** en el Nido. La animación no se abre sola.
3. Al abrirlo nace un dinosaurio. Los adultos producen ámbar de forma pasiva.
4. Libera ejemplares para obtener esencia.
5. Compra mejoras con ámbar y esencia: ritmo del nido, incubadoras, incubación, capacidad, suerte y producción.
6. Cruza dos adultos de la misma especie. El simulador muestra la distribución exacta de los genes visibles antes de confirmar.
7. Completa combinaciones en el Dinodex: patrón, color primario, cresta y mutación.
8. Cuando quieras, haz la Gran Migración: reinicia la colonia, conserva hasta 3 fundadores y gana puntos de legado permanentes.

## Transparencia

- El botón **Ver probabilidades exactas** del Nido muestra las tasas base y efectivas del motor, las garantías y cada mutación con su probabilidad.
- Las barras de pity están siempre visibles. No se reinician con el prestigio.
- El **Registro** guarda fecha, origen, rareza, especie, genes, mutación, garantías, semilla y rango de tiradas de cada apertura. Compara las tasas reales del nido con las teóricas.
- La apertura no usa destellos que insinúen rarezas falsas. La cáscara se agrieta poco a poco durante 2,35 segundos, se abre en dos mitades y el dinosaurio sale con un efecto de sonido. El botón **CLIC PARA SALTAR** queda centrado y también responde a `Esc` o `Espacio`; el modo tranquilo la desactiva.
- No hay anuncios, compras, moneda real, urgencia artificial ni falsos “casi lo consigues”. El modo tranquilo desactiva animaciones y el tope diario es opcional.

## Ajustar `config.lua`

Casi todo el balance vive en `src/game/config.lua`:

- `rates.rarity`, `rates.pity` y `rates.mutationChance`: probabilidades y garantías.
- `time`: intervalos, incubación, cruce, capacidad y tope offline.
- `starting`: ámbar, esencia, huevos y huecos iniciales.
- `species`, `patterns`, `colors`, `secondaryColors`, `crests`, `mutations`: contenido y paletas.
- `upgrades`: coste base, crecimiento, máximo y efecto de cada mejora.
- `prestige` y `dinodex`: requisitos, bonus y multiplicadores.

El motor y la interfaz leen de ese archivo. Si cambias una tasa, los tests y el panel de probabilidades reflejan el cambio; no hay porcentajes duplicados en la interfaz.

## Supuestos del MVP

La especificación no fijaba estos detalles; se resolvieron así:

1. **Rareza en cruces**: el hijo parte de la rareza mayor de los padres y tiene una probabilidad de subir un nivel (`crossRarityUpgradeChance` + suerte de los padres). Se muestra en el simulador.
2. **Legendario**: la elección entre dos especies se aplica a los huevos del nido, que son los que usan la tirada de rareza. Un legendario de cruce conserva la especie de sus padres; el cruce no sortea especie.
3. **Pity de mutación**: lo comparten nido y cruces. El pity de rareza solo se aplica al nido, porque la rareza de un cruce es heredada.
4. **Dinodex**: la “combinación de color” usa el color primario. El secundario se hereda, se muestra en la ficha y en el registro, pero no multiplica las variantes del catálogo (4 patrones × 4 colores × 3 crestas × 6 estados de mutación = 288 por especie, 1.728 en total).
5. **Genes funcionales**:
   - Productividad: +12 % de ámbar por punto.
   - Fertilidad: −6 % de tiempo de cruce por punto.
   - Resistencia: −4 % de tiempo de madurez por punto.
   - Suerte: +1 % de probabilidad de subir rareza en un cruce por punto.
6. **Tope diario**: limita los huevos que genera el nido, no los huevos de cruce.
7. **Progreso offline**: el tope de 8 horas se aplica al ámbar y a los huevos del nido. Las incubadoras y los cruces ya iniciados terminan; sus resultados se muestran al volver.
8. **Huevo inicial**: la partida nueva empieza con un huevo y una incubadora. Tras la Gran Migración también se entrega un huevo para arrancar.
9. **Requisito de prestigio**: 15 huevos abiertos desde la última migración, sin aperturas pendientes y sin cruce en curso. Los fundadores se eligen entre los ejemplares actuales.
10. **Cruces**: no se pueden cancelar. Los padres quedan ocupados hasta terminar. Si el nido está lleno, el huevo de cruce espera y tiene prioridad sobre el siguiente huevo del nido.
11. **Registro**: conserva las últimas 2.000 aperturas; las estadísticas comparativas son de toda la partida. Se guardan semilla y contador para auditar.
12. **Mutaciones**: las cinco son equiprobables; la probabilidad total es `mutationChance` y cada una recibe una quinta parte.
13. **Especie**: la tirada de especie es uniforme entre las seis. Los cruces solo son entre la misma especie.
14. **Colores**: paleta fija de cuatro primarios y cuatro secundarios; la herencia usa dominancia simple.
15. **Guardado**: JSON propio, clave `version` y migraciones. La lectura/escritura la hace `main.lua`; `src/game/save.lua` no toca `love.filesystem`.
16. **Audio**: música y efectos se sintetizan al arrancar y no usan archivos externos. El audio se puede silenciar; si el dispositivo falla, el juego continúa en silencio.
17. **Pity**: la garantía sustituye la tirada en el huevo número `rareAt`, `legendaryAt` o `mutationAt` desde el último resultado correspondiente. Los contadores se reinician solo al obtener ese resultado.
18. **Rendimiento**: la rejilla del criadero solo dibuja las tarjetas visibles. Se probó la carga y el desplazamiento con 200 ejemplares; la tasa de 60 FPS depende de la GPU (el entorno de desarrollo usa render por software y no permite validarla).
19. **Fuente**: Pixelify Sans se incluye bajo SIL OFL para acercar la interfaz a la referencia pixel-art; no se usan imágenes externas.

## Empaquetar un `.love`

```bash
zip -9 -r criadero-ambar.love . \
  -x "*.git*" "tools/*" "*.love" "save.json"
```

Luego se puede abrir el archivo con LÖVE o distribuir el `.love`.

## Fuera de alcance

Multijugador, cuentas, ranking, intercambio, compras con dinero real, anuncios, cruces entre especies, edición genética, audio grabado, imágenes o sonidos externos.
