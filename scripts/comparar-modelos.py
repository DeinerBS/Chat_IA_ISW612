#!/usr/bin/env python3
"""Compara modelos de Ollama: tamaño, RAM, tiempo a primera respuesta, tokens/s y respuestas.
Uso: python3 scripts/comparar-modelos.py   (desde la raíz del repo, sin sudo)
Genera docs/evidencia/comparacion-modelos.md"""
import json, subprocess, time, urllib.request, os, re

MODELOS = ["llama3.2:1b", "qwen2.5:1.5b", "gemma3:1b"]
URL = "http://127.0.0.1:11434"
SISTEMA = "Eres el asistente interno de una empresa. Responde en español, de forma breve, clara y profesional."
PREGUNTAS = [
    "Explica en dos oraciones qué es un firewall.",
    "Redacta un correo breve para solicitar vacaciones del 20 al 24 de diciembre.",
    "Un producto cuesta 12 500 colones y se le suma 13 % de IVA. ¿Cuál es el precio final? Muestra el cálculo.",
    "Resume en tres puntos las ventajas de usar contraseñas largas.",
    "¿Cuál es la capital de Costa Rica y en qué provincia está?",
]
SALIDA = "docs/evidencia/comparacion-modelos.md"


def api(ruta, datos=None):
    req = urllib.request.Request(URL + ruta, data=json.dumps(datos).encode() if datos else None,
                                 headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=300) as r:
        return json.loads(r.read())


def ram_modelo(modelo):
    # Memoria que ocupa el modelo cargado, según la API (equivale a "ollama ps")
    for m in api("/api/ps").get("models", []):
        if m["name"] == modelo:
            return m.get("size", 0) / 1024**3
    return 0.0


def tam_disco(modelo):
    for m in api("/api/tags")["models"]:
        if m["name"] == modelo:
            return m["size"] / 1024**3
    return 0.0


resultados, respuestas = [], {}
for modelo in MODELOS:
    print(f"== {modelo}: descargando (si hace falta)...", flush=True)
    subprocess.run(["ollama", "pull", modelo], check=True)
    subprocess.run(["ollama", "stop", modelo], capture_output=True)  # empezar en frío
    filas = []
    for i, p in enumerate(PREGUNTAS, 1):
        r = api("/api/generate", {"model": modelo, "system": SISTEMA, "prompt": p, "stream": False,
                                  "options": {"temperature": 0.2, "num_predict": 300}})
        ns = 1e9
        primer = (r.get("load_duration", 0) + r.get("prompt_eval_duration", 0)) / ns
        tps = r["eval_count"] / (r["eval_duration"] / ns) if r.get("eval_duration") else 0
        filas.append({"carga": r.get("load_duration", 0) / ns, "primer": primer, "tps": tps,
                      "total": r["total_duration"] / ns, "tokens": r["eval_count"]})
        respuestas.setdefault(modelo, []).append(r["response"].strip())
        print(f"   P{i}: primera respuesta {primer:.2f} s · {tps:.1f} tok/s · total {filas[-1]['total']:.1f} s", flush=True)
    ram = ram_modelo(modelo)
    calientes = filas[1:]  # sin la primera (incluye la carga del modelo)
    resultados.append({
        "modelo": modelo, "disco": tam_disco(modelo), "ram": ram,
        "carga": filas[0]["carga"],
        "primer": sum(f["primer"] for f in calientes) / len(calientes),
        "tps": sum(f["tps"] for f in filas) / len(filas),
        "total": sum(f["total"] for f in calientes) / len(calientes),
    })
    subprocess.run(["ollama", "stop", modelo], capture_output=True)  # liberar RAM para el siguiente

os.makedirs(os.path.dirname(SALIDA), exist_ok=True)
with open(SALIDA, "w", encoding="utf-8") as f:
    f.write("# Comparación de modelos\n\n")
    f.write(f"Fecha: {time.strftime('%Y-%m-%d %H:%M')} · VM: 2 vCPU, ~4 GB RAM, sin GPU · temperatura 0.2\n\n")
    f.write("| Modelo | Tamaño en disco | RAM cargado | Carga en frío | Primera respuesta (prom.) | Tokens/s (prom.) | Respuesta completa (prom.) |\n")
    f.write("|---|---|---|---|---|---|---|\n")
    for r in resultados:
        f.write(f"| {r['modelo']} | {r['disco']:.2f} GB | {r['ram']:.2f} GB | {r['carga']:.1f} s | "
                f"{r['primer']:.2f} s | {r['tps']:.1f} | {r['total']:.1f} s |\n")
    f.write("\n*Primera respuesta* = carga + lectura del prompt (sin streaming). Los promedios de tiempo excluyen la primera pregunta, que incluye cargar el modelo.\n\n")
    f.write("## Respuestas (para evaluar la calidad)\n\n")
    for i, p in enumerate(PREGUNTAS):
        f.write(f"### P{i+1}. {p}\n\n")
        for modelo in MODELOS:
            texto = re.sub(r"\n{2,}", "\n", respuestas[modelo][i]).replace("\n", "<br>")
            f.write(f"- **{modelo}:** {texto}\n")
        f.write("\n")
print(f"\nListo: {SALIDA}")
