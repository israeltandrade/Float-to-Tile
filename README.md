# 🔷 Float-to-Tile: Tiling Companion for Floating Window Managers

## 🚀 Missão do Projeto
O **Float-to-Tile** é um conjunto de scripts modulares escrito inteiramente em **Bash** (Shell Script) e utilizando as ferramentas nativas do **X11** (como `xrandr`, `wmctrl` e `xdotool`) para adicionar funcionalidades robustas de *Tiling Window Manager* em ambientes de desktop que usam o paradigma *Stacking* (Flutuante) por padrão.

O objetivo é fornecer uma experiência de *tiling* leve, rápida e com zero dependências externas complexas, integrando-se perfeitamente em ambientes como XFCE, GNOME ou MATE, sem a necessidade de migrar para um WM dedicado (como i3 ou Awesome).

## 🧩 Arquitetura Modular
O projeto é dividido em módulos orquestrados pelo script principal (`00_main.sh`):

1.  **Módulos de Coleta de Dados (`NN_*.sh`):** Scripts para capturar o estado atual do sistema (geometria da tela, IDs de janelas, posições, etc.).
2.  **Módulos de Ação (`A-NN_*.sh`):** Scripts para executar ações de *tiling* (redimensionar, mover, focar, etc.).

Todo o *tiling* é baseado na manipulação das propriedades das janelas (via `wmctrl` e `xdotool`) e no conhecimento exato da geometria do *viewport* (via `xrandr`).

## ⚙️ Dependências
O projeto depende apenas de utilitários de linha de comando amplamente disponíveis em ambientes X11 baseados em Debian:

* `xrandr` (Para geometria da tela/monitor)
* `wmctrl` (Para listar e manipular janelas)
* `xdotool` (Para obter a janela ativa e enviar comandos de foco)
* `awk`, `grep`, `cut` (Para processamento de dados)

---
Para informações detalhadas sobre cada módulo, consulte a pasta `Documentation/`.