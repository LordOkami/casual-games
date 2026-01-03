# Casual Games Collection

15 juegos casuales independientes listos para publicar, desarrollados para Godot 4.5.1.

## Juegos Incluidos

| # | Juego | Descripción | Mecánica |
|---|-------|-------------|----------|
| 01 | **Flappy Clone** | Vuela a través de tuberías | Tap para volar |
| 02 | **Stack Tower** | Apila bloques perfectamente | Tap para soltar bloque |
| 03 | **Color Switch** | Pasa por obstáculos del mismo color | Tap para saltar |
| 04 | **Endless Runner** | Corre y salta obstáculos | Tap/doble-tap para saltar |
| 05 | **2048** | Combina números deslizando | Swipe en 4 direcciones |
| 06 | **Snake** | Clásico juego de la serpiente | Swipe para cambiar dirección |
| 07 | **Breakout** | Destruye bloques con la pelota | Arrastra paddle |
| 08 | **Tap Dash** | Corre y gira en las esquinas | Tap en giros |
| 09 | **Ball Bounce** | Rebota en plataformas con timing | Tap cerca de plataformas |
| 10 | **Whack-a-Mole** | Golpea topos rápidamente | Tap en topos |
| 11 | **Doodle Jump** | Salta en plataformas hacia arriba | Arrastra para mover |
| 12 | **Pong** | Clásico juego de paddle vs IA | Arrastra paddle |
| 13 | **Memory Match** | Encuentra pares de cartas | Tap en cartas |
| 14 | **Fruit Slice** | Corta frutas, evita bombas | Swipe para cortar |
| 15 | **Tetris** | Bloques que caen clásico | Tap=rotar, swipe=mover |

## Estructura de Cada Proyecto

```
XX_nombre_juego/
├── project.godot      # Archivo de proyecto Godot 4.5.1
├── icon.svg           # Icono del juego
├── autoload/
│   ├── game_manager.gd   # Gestión de puntuación y estado
│   └── audio_manager.gd  # Sonidos procedurales
├── scenes/
│   ├── main_menu.tscn    # Menú principal
│   ├── main_menu.gd
│   ├── game.tscn         # Escena del juego
│   ├── game.gd
│   ├── game_ui.tscn      # UI compartida
│   └── game_ui.gd
└── assets/              # Para recursos adicionales
```

## Cómo Usar

1. **Abrir un juego**: Abre cualquier carpeta `XX_nombre_juego/project.godot` con Godot 4.5.1
2. **Ejecutar**: Presiona F5 o el botón Play
3. **Personalizar**: Cada proyecto es independiente, modifica sin afectar otros

## Características

- ✅ **15 juegos completos** listos para publicar
- ✅ **Proyectos independientes** - cada juego es standalone
- ✅ **Godot 4.5.1** compatible
- ✅ **Mobile-first** - optimizados para táctil (720x1280)
- ✅ **Sonidos procedurales** - sin archivos de audio externos
- ✅ **High scores** guardados localmente
- ✅ **UI responsive** con pausa y game over

## Personalización Rápida

### Cambiar nombre del juego:
Edita `scenes/main_menu.tscn` y modifica `game_name`

### Cambiar color del tema:
Edita `scenes/main_menu.tscn` y modifica `primary_color`

### Añadir sonidos reales:
Reemplaza las funciones en `autoload/audio_manager.gd`

## Exportación

Cada proyecto está configurado para exportar a:
- Android (armeabi-v7a, arm64-v8a)
- iOS (arm64)

Para exportar: Proyecto → Exportar → Selecciona plataforma

## Regenerar Proyectos

Si necesitas regenerar la estructura base:
```bash
python3 generate_projects.py
```

---
Creado con Claude Code usando metodología de automatización inspirada en Lazy Bird.
