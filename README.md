# Tarea \#3 de analisis de algoritmos

Benchmark de algoritmos de ordenamiento (Bubble, Selection, Insertion, Quick,
Heap y Merge sort) sobre arreglos de enteros aleatorios.

El repositorio tiene dos partes:

| Carpeta | Lenguaje | Que hace |
| --- | --- | --- |
| [`sorter/`](sorter/) | Zig | Ejecuta los algoritmos y escribe los tiempos en un CSV. |
| [`normalizer/`](normalizer/) | Python | Junta uno o varios CSV del `sorter` en un reporte de Excel (`.xlsx`). |


## Prerequisitos

El _source code_ esta escrito en [zig 0.17.1](https://ziglang.org/download/).

> [!IMPORTANT]
> Al ser este un lenguaje todavia en desarrollo es importante contar con la
> version en especifico para asegurar que se pueda compilar correctamente.

Para el `normalizer` se necesita Python `>= 3.10` (se desarrollo con 3.14) y,
opcionalmente, [`uv`](https://docs.astral.sh/uv/).


## Instalar zig localmente (sin instalarlo globalmente)

Zig se distribuye como un unico archivo comprimido que no necesita instalador
ni permisos de administrador: basta con descomprimirlo dentro del proyecto y
usar el ejecutable desde ahi.

### Linux / macOS

Desde la raiz del repositorio:

```sh
# Elegir el archivo segun la plataforma:
#   Linux x86_64:        zig-x86_64-linux-0.17.1.tar.xz
#   Linux ARM64:         zig-aarch64-linux-0.17.1.tar.xz
#   macOS Apple Silicon: zig-aarch64-macos-0.17.1.tar.xz
#   macOS Intel:         zig-x86_64-macos-0.17.1.tar.xz
ZIG=zig-x86_64-linux-0.17.1

mkdir -p .zig
curl -L "https://ziglang.org/download/0.17.1/$ZIG.tar.xz" | tar -xJ -C .zig
mv ".zig/$ZIG" .zig/zig-0.17.1

# Verificar
./.zig/zig-0.17.1/zig version   # -> 0.17.1
```

Para no escribir la ruta completa cada vez, se puede agregar al `PATH`
**solo en la terminal actual** (no modifica nada del sistema):

```sh
export PATH="$PWD/.zig/zig-0.17.1:$PATH"
zig version   # -> 0.17.1
```

### Windows (PowerShell)

```powershell
$ZIG = "zig-x86_64-windows-0.17.1"
New-Item -ItemType Directory -Force .zig | Out-Null
Invoke-WebRequest "https://ziglang.org/download/0.17.1/$ZIG.zip" -OutFile ".zig\$ZIG.zip"
Expand-Archive ".zig\$ZIG.zip" -DestinationPath .zig
Rename-Item ".zig\$ZIG" "zig-0.17.1"

# Solo para la sesion actual
$env:Path = "$PWD\.zig\zig-0.17.1;$env:Path"
zig version
```

> [!NOTE]
> Si algun enlace falla, todos los archivos de la version estan listados en
> <https://ziglang.org/download/> bajo **0.17.1**. La carpeta `.zig/` ya esta en el
> `.gitignore`, asi que el compilador no se sube al repositorio.

Para "desinstalarlo" basta con borrar la carpeta `.zig/`. Zig tambien guarda
cache de compilacion en `sorter/.zig-cache/` y en `~/.cache/zig` (en Windows
`%LOCALAPPDATA%\zig`), que se pueden borrar sin problema.


## Compilar y ejecutar el `sorter`

Todos los comandos se ejecutan desde `sorter/`:

```sh
cd sorter
```

> [!IMPORTANT]
> Compilar siempre con `-Doptimize=ReleaseFast` al medir tiempos. El modo por
> defecto (`Debug`) incluye chequeos de seguridad que hacen los algoritmos
> varias veces mas lentos y los resultados no serian representativos.

### Opcion 1: compilar y ejecutar en un paso

Los argumentos del programa van despues de `--`:

```sh
zig build run -Doptimize=ReleaseFast -- --min 10000 --mid 100000 --max 1000000
```

### Opcion 2: compilar una vez y ejecutar el binario

```sh
zig build -Doptimize=ReleaseFast
./zig-out/bin/sorter --min 10000 --mid 100000 --max 1000000
```

En Windows el binario es `zig-out\bin\sorter.exe`.

### Pruebas

```sh
zig build test --summary all                         # Debug, con chequeos de seguridad
zig build test --summary all -Doptimize=ReleaseFast  # mismo modo que las mediciones
```

Que se prueba:

- **Algoritmos** (`src/algorithms.zig`): cada `pub fn` del archivo se prueba
  automaticamente (un algoritmo nuevo queda cubierto sin tocar los tests). El
  resultado se compara contra `std.mem.sort`, lo que verifica que quede
  ordenado **y** que sea una permutacion de la entrada. Casos: arreglos vacios,
  de 1 y 2 elementos, ya ordenados, invertidos, todos iguales, muchos
  duplicados, valores extremos (`0` y `maxInt(i32)`), patrones (organ pipe,
  sawtooth) y datos aleatorios con semilla fija en tamaños de 2 a 4096.
- **CLI** (`src/cliArgs.zig`): valores por defecto, flags cortos y largos,
  orden de los flags, flags sin valor, numeros invalidos, negativos o fuera de
  rango, `--iterations 0`, argumentos desconocidos y que `--help` liste todos
  los algoritmos.

### Uso

```text
$ ./zig-out/bin/sorter --help
sorter - benchmarks sorting algorithms over arrays of random integers

Usage:
  sorter [--min <n>] [--mid <n>] [--max <n>] [options]
  zig build run -Doptimize=ReleaseFast -- [--min <n>] [--mid <n>] [--max <n>] [options]

Dataset sizes (at least one is required; each is a positive integer):
      --min, --min-array-size <n>  Number of elements of the "small" dataset.
      --mid, --mid-array-size <n>  Number of elements of the "medium" dataset.
      --max, --max-array-size <n>  Number of elements of the "large" dataset.

  Each element is an i32 (4 bytes), so 1,000,000,000 elements need ~3.73 GiB of RAM.

Options:
  -i, --iterations <n>             Times every algorithm runs per dataset size,
                                   1-255. (default: 3)
  -o, --out-csv <path>             CSV file where results are written.
                                   Relative or absolute path. (default: out.csv)
  -sd, --seed <n>                  Seed that will be used to fill the dataset,
                                   Accepts: Binary (0b), Octal (0o), Hex (0x) and decimal formats. (default: 0x5eed)
  -s, --skip <alg[,alg...]>        Algorithms to skip (written as "skipped" in the CSV),
                                   comma separated, lowercase. Available:
                                     - bubble
                                     - selection
                                     - insertion
                                     - quick
                                     - heap
                                     - merge
  -h, --help                       Show this help and exit.

Output:
  One CSV row per (size, iteration): DataSize,Iteration,<Algorithm> Ms,...
  Cells are "<n> ms", "skipped", or "N/A" if the algorithm failed.

Examples:
  sorter --min 10000 --mid 100000 --max 1000000
  sorter --max 100000000 -i 5 -s bubble,selection,insertion -o executions/100M.csv
```

Notas:

- Se debe indicar al menos uno de `--min`, `--mid` o `--max`. Cada tamaño se
  ejecuta `--iterations` veces, y en cada iteracion el arreglo se vuelve a
  llenar con datos aleatorios antes de cada algoritmo.
- El dato aleatorio es determinista: la semilla por defecto es `0x5eed` y se
  puede cambiar con `--seed` (acepta decimal, `0x`, `0b` y `0o`). Cada tamaño
  usa `semilla + tamaño` y cada iteracion suma ademas el numero de iteracion,
  asi que todos los algoritmos de una misma fila ordenan exactamente el mismo
  arreglo.
- El archivo de salida se sobreescribe si ya existe. La carpeta donde se
  escribe **debe existir** (p. ej. `mkdir -p ../executions`).
- Los algoritmos O(n²) (`bubble`, `selection`, `insertion`) se vuelven
  impracticables con arreglos grandes; para esos casos conviene usar `--skip`.

### Ejemplo completo

```sh
mkdir -p ../executions
zig build -Doptimize=ReleaseFast

./zig-out/bin/sorter --min 10000 --mid 100000 --max 1000000 -o ../executions/small.csv
./zig-out/bin/sorter --max 100000000 -i 3 -s bubble,selection,insertion -o ../executions/100M.csv
```


## Ejecutar el `normalizer`

El `normalizer` lee los CSV generados por el `sorter` y produce un reporte de
Excel con estadisticas y graficas. Los detalles del reporte estan en
[`normalizer/README.md`](normalizer/README.md).

Todos los comandos se ejecutan desde `normalizer/`:

```sh
cd normalizer
```

| Flag | Significado |
| --- | --- |
| `-d, --dir DIR` | lee todos los `*.csv` de `DIR` |
| `-f, --file FILE` | lee un solo CSV (se puede repetir) |
| `-o, --output PATH` | archivo `.xlsx` de salida (por defecto `report.xlsx`) |
| `--discard-notes` | no conservar las notas escritas a mano en un reporte existente |

### Con `uv` (recomendado)

`uv` crea el entorno virtual, instala la version de Python de
`.python-version` y las dependencias fijadas en `uv.lock` automaticamente:

```sh
uv run normalizer -d ../executions -o ../report.xlsx
```

Opcionalmente, para solo preparar el entorno sin ejecutar nada:

```sh
uv sync
```

### Con `pip` + `python`

Crear un entorno virtual dentro de `normalizer/` e instalar el paquete en el:

```sh
python3 -m venv .venv

# Activar el entorno
source .venv/bin/activate          # Linux / macOS
# .venv\Scripts\Activate.ps1       # Windows (PowerShell)

pip install -e .
```

Con el entorno activado se puede ejecutar de cualquiera de estas formas:

```sh
normalizer -d ../executions -o ../report.xlsx
# o
python -m normalizer -d ../executions -o ../report.xlsx
```

Para salir del entorno: `deactivate`.

> [!NOTE]
> `pip install -e .` instala las dependencias declaradas en `pyproject.toml`
> (`openpyxl`, `xlsxwriter`) pero no usa las versiones exactas de `uv.lock`.
> Para replicar exactamente el entorno usar `uv`.


## Specs

Equipo en el que se ejecutaron las mediciones:

| Componente | Detalle |
| --- | --- |
| Equipo | Dell Precision 3570 (laptop) |
| CPU | 12th Gen Intel Core i7-1265U — 10 nucleos (2 P-cores + 8 E-cores), 12 hilos, 400 MHz – 4.8 GHz |
| Cache | L1d 352 KiB · L1i 576 KiB · L2 6.5 MiB · L3 12 MiB |
| RAM | 16 GB (15 GiB utilizables) + 3.4 GiB de swap |
| Almacenamiento | NVMe T-FORCE TM8FFE512G 512 GB (principal) · NVMe Micron 2550 256 GB |
| Sistema operativo | Void Linux, kernel 6.18.64 (x86_64) |
| CPU governor | `powersave` |
| Zig | 0.17.1 |
| Python | 3.14.8 |

> [!NOTE]
> Es una laptop con CPU de bajo consumo (serie U) y governor `powersave`, por
> lo que los tiempos pueden variar segun temperatura, carga del sistema y si
> esta conectada a la corriente.
