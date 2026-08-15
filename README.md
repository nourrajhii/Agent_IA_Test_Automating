# Test Automating

Agent IA de test automatisé : donnez un code HTML/JS/JSX, il génère et exécute des scénarios de test Selenium pour toutes les fonctionnalités de l'interface.

```
HTML/JS/JSX → Analyse UI → Scénarios de test → Scripts Selenium → Exécution → Rapport
```

Un LLM local (Ollama) analyse le code, détecte les éléments interactifs, comprend les fonctionnalités réelles de la page, génère un scénario de test par fonctionnalité, écrit le script Selenium correspondant et l'exécute. Résultat diffusé en temps réel via SSE. **100% local.**

**Stack** — Frontend : React, Vite, SSE. Backend : FastAPI, Selenium, webdriver-manager, Ollama, LangGraph.

## Features

- **Analyse UI** : parsing HTML + fallback LLM (JSX/React), détection de zone fonctionnelle par élément (nav, footer, formulaires, auth, sous-menus au survol, sélecteur de langue), mode "URL réelle" via Chrome headless pour les SPA
- **Compréhension de l'app** : résumé compact de l'interface envoyé au LLM en un seul appel pour déterminer type/but/capacités métier, puis regroupement des features en parcours utilisateur (ex. connexion → dashboard)
- **Génération de scénarios** : détection déterministe (sans LLM) des zones à règles connues (nav, footer, actualités...), scénarios toujours dédiés pour Connexion/Inscription/Mot de passe oublié/Langue, titres systématiquement fonctionnels
- **Scripts & exécution** : résolution de chaque étape vers l'élément UI réel (similarité de texte), scripts Selenium avec repli XPath, exécution parallèle isolée (plusieurs Chrome headless), retry auto (déterministe ou piloté par agent LLM)
- **Rapport** : fichier HTML autonome (screenshots en base64), diagnostic intelligent des échecs + suggestion de correctif, streaming SSE, commence directement sur les scénarios (aucun détail technique en avant)

## Architecture

```
test-auto/
├── app/
│   ├── models/schemas.py
│   ├── services/              # agents spécialisés du pipeline
│   ├── config.py
│   └── main.py                # API + pipeline SSE
├── frontend/
│   ├── src/{App.jsx,main.jsx}
│   └── Dockerfile
├── reports/                    # runtime
├── uploads/                    # runtime
├── screenshots/                 # runtime
├── Dockerfile
├── docker-compose.yml
├── run.py
└── requirements.txt
```

## Pipeline (LangGraph)

Pas une chaîne linéaire : un graphe d'agents spécialisés, certains appellent le LLM, d'autres sont 100% déterministes (plus rapides, résultats garantis).

```
Analyse UI ──► Compréhension de l'app ──► Détection déterministe des zones
   (parsing +      (1 appel LLM : type,       (nav/footer/langue... → scénario
   fallback LLM)     but, capacités)            direct, sans LLM)
                                                        │
                                                        ▼
                              Extraction de features restantes (LLM, par lot)
                                                        │
                                                        ▼
                                 Regroupement en parcours utilisateur (LLM)
                                                        │
                                                        ▼
                              Plan de test + génération des scénarios finaux
                                                        │
                                                        ▼
                    Génération scripts Selenium (résolution étape → élément UI)
                                                        │
                                                        ▼
                         Exécution parallèle (Chrome headless, retry + XPath)
                                                        │
                                                        ▼
                                                     Rapport
```

## Déploiement Docker

Architecture 3 conteneurs : **Ollama** (LLM local) → **backend** (FastAPI + Selenium + Tesseract) → **frontend** (React/Vite buildé, servi par nginx). Un conteneur `ollama-init` éphémère télécharge les modèles une seule fois au premier lancement (~5-10 Go).

```bash
cp .env.example .env      # ajuster les modèles / concurrency si besoin
docker compose up --build
```

| Service | Rôle | Port hôte |
|---|---|---|
| `ollama` | Sert les modèles LLM (texte, vision, agent) | 11434 |
| `ollama-init` | Pull les modèles puis s'arrête (`restart: no`) | — |
| `backend` | API FastAPI, pipeline LangGraph, Selenium | 8000 |
| `frontend` | Build Vite servi par nginx | 5173 |

**Variables `.env` principales** :

```bash
TEXT_MODEL=llama3.2:1b
VISION_MODEL=llava:7b
AGENT_MODEL=llama3.1:8b
EXECUTION_CONCURRENCY=3        # instances Chrome headless en parallèle
SCENARIO_GEN_CONCURRENCY=2     # générations LLM en parallèle
VITE_API_URL=http://localhost:8000   # remplacer par l'IP/domaine en déploiement distant
```

**Points notables du setup** :
- Le backend attend qu'Ollama soit `healthy` *et* qu'`ollama-init` ait fini de puller les modèles avant de démarrer (`depends_on: condition: service_completed_successfully`)
- Healthcheck Ollama basé sur `ollama list` (le binaire de l'image), pas `curl`/`wget` — non garantis dans l'image `ollama/ollama`
- `shm_size: 2gb` sur le backend : Chrome headless a besoin de plus que les 64 Mo de `/dev/shm` par défaut, sinon il peut crasher sur des pages lourdes
- `reports/`, `screenshots/`, `uploads/` sont montés en volumes pour persister entre redémarrages
- GPU NVIDIA : bloc `deploy.resources.reservations.devices` commenté dans le service `ollama`, à activer si `nvidia-container-toolkit` est installé (accélère surtout `llava:7b`)

## Getting Started (sans Docker)

Prérequis : Python 3.10+, Node.js 18+, Chrome, Ollama

```bash
ollama pull llama3.2:3b && ollama serve

# Backend
python -m venv venv && source venv/bin/activate
pip install -r requirements.txt
python run.py

# Frontend
cd frontend && npm install && npm run dev
```
