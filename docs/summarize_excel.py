"""Genera un resumen conciso de todos los casos de prueba del Excel."""
import json
import sys
import io

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

with open('docs/casos_prueba_inventory.json', 'r', encoding='utf-8') as f:
    inventory = json.load(f)

all_modules = {}

for sheet_name, rows in inventory.items():
    if not rows:
        continue
    
    # La primera fila es el título del módulo
    module_title = rows[0][0] if rows[0][0] else sheet_name
    
    # Encontrar la fila de encabezados
    header_idx = None
    for i, row in enumerate(rows):
        if row[0] == '#':
            header_idx = i
            break
    
    if header_idx is None:
        for i, row in enumerate(rows):
            if row and row[1] == 'Escenario':
                header_idx = i
                break
    
    casos = []
    if header_idx is not None:
        for row in rows[header_idx + 1:]:
            if row[0] and str(row[0]).startswith('CP'):
                casos.append({
                    'num': str(row[0]),
                    'escenario': str(row[1]) if row[1] else '',
                    'precondicion': str(row[2]) if row[2] else '',
                    'accion': str(row[3]) if row[3] else '',
                    'resultado_esperado': str(row[4]) if row[4] else '',
                })
    
    all_modules[sheet_name] = {
        'titulo': module_title,
        'casos': casos
    }

# Guardar resumen
with open('docs/casos_prueba_resumen.json', 'w', encoding='utf-8') as f:
    json.dump(all_modules, f, ensure_ascii=False, indent=2)

print(f"Total modulos: {len(all_modules)}")
total_cp = 0
for rf, data in all_modules.items():
    n = len(data['casos'])
    total_cp += n
    titulo = data['titulo'].encode('ascii', 'replace').decode()[:55]
    print(f"  {rf} -- {titulo} -> {n} CP")
print(f"\nTotal CPs: {total_cp}")
