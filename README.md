# Lébénam Triage

> Application de démo de la keynote **Flutter in the Agentic Era: From West African Clinics to Toyota RAV4** (DevFest Cloud Abidjan 2026).

Un assistant de triage médical pour les cliniques d'Afrique de l'Ouest, là où le réseau est faible et où tout le monde ne lit pas. Le patient décrit ses symptômes, par écrit ou **à voix haute** (Gemini écoute l'audio directement), et **Gemini compose l'interface Flutter à la volée** à partir d'un catalogue de widgets. Aucun écran de triage n'est codé en dur : chaque réponse de l'agent est une nouvelle interface.

Toute l'app est en français : l'interface, le prompt, les réponses de l'agent et le mode hors-ligne.

⚠️ Démonstration technique : ne remplace pas un avis médical. L'agent ne donne jamais de diagnostic certain : il évalue l'urgence et oriente vers un soignant.

Le même socle a servi à Agble (conseil agricole, DevFest Lomé 2026). Même moteur, même protocole, autre catalogue.

---

## Stack

| Package | Rôle |
|---|---|
| [`genui`](https://pub.dev/packages/genui) `^0.10.3` | SDK GenUI : `SurfaceController`, `Conversation`, `Surface`, protocole A2UI |
| [`genui_catalog`](https://pub.dev/packages/genui_catalog) `^0.5.0` | 18 CatalogItems prêts à l'emploi, combinés aux composants de triage |
| `firebase_ai`, `firebase_app_check` | Gemini via Firebase AI Logic : aucune clé dans l'app |
| `flutter_edge_ai`, `flutter_edge_ai_litertlm` | Gemma 4 E2B sur le téléphone, pour le hors-ligne |
| `json_schema_builder` | Schémas JSON des CatalogItems |
| `record` | Message vocal : micro en PCM 16 kHz mono, envoyé en WAV |
| `url_launcher` | Ouvre le téléphone pour les appels (urgences, clinique) |
| `google_fonts`, `flutter_animate`, `gap`, `flutter_svg` | Design (charte Lébénam), logo animé |

> `genui` est marqué discontinué sur pub.dev (remplacé par `a2ui_flutter`). La migration n'est pas faite.

---

## Lancer l'app

Aucune clé Gemini dans l'app : les requêtes passent par **Firebase AI Logic** (la clé reste côté serveur) et **App Check** prouve qu'elles viennent de l'app.

Le projet est épinglé sur **Flutter 3.47.9** avec [fvm](https://fvm.app) (`.fvmrc`) : Agentic Hot Reload demande Dart 3.12 ou plus.

```bash
fvm install                      # une fois
fvm flutter pub get
cp .env.example.json .env.json   # numéros de téléphone, modèle, jeton App Check
fvm flutter run -d <id du téléphone> --dart-define-from-file=.env.json
```

- **Firebase** : projet `lebenamtriage`. Dans la console, activez **Firebase AI Logic** (Gemini Developer API).
- **App Check** : en debug, l'app utilise `APP_CHECK_DEBUG_TOKEN` de `.env.json` (un UUID). Enregistrez-le dans Firebase → App Check → *Apps* → ⋮ → *Gérer les jetons de débogage*. Le web n'active pas App Check.
- **Appels** : `EMERGENCY_PHONE` (118 par défaut) et `CLINIC_PHONE` dans `.env.json`. L'agent choisit seulement qui appeler, jamais le numéro.
- **Modèle** : `GEMINI_MODEL` dans `.env.json` (par défaut `gemini-3.8-flash`).
- **Micro** : l'autorisation est demandée au premier appui.
- La démo tourne sur Android. Sur macOS, App Check demande une app signée avec une équipe Apple : ce n'est pas configuré ici.

```bash
fvm flutter test          # rejoue le prompt et le hors-ligne dans le vrai pipeline genui, sans LLM
fvm dart analyze lib test
```

---

## Architecture

```
lib/
  main.dart                      Firebase + App Check, thème, puis runApp
  core/
    constants/prompts.dart       system prompt + 14 exemples few-shot (français)
    phone/dialer.dart            numéros des urgences et de la clinique
  features/
    triage/
      triage_agent.dart          ★ la boucle agent GenUI ↔ Gemini (texte + audio), repli hors-ligne
      offline/offline_triage.dart   règles locales : même protocole A2UI, même catalogue, sans IA
      offline/on_device_model.dart  Gemma sur le téléphone : comprend, ne compose pas
      triage_screen.dart         Surface GenUI + barre de saisie en bas
      demo/guard_demo_sheet.dart démo de la garde Dart (propriété inventée, valeur hors bornes)
  catalog/
    catalog_items.dart           ★ le contrat LLM ↔ Flutter (7 items de triage + 18 genui_catalog)
    strict_props.dart            la garde Dart : rejette les propriétés inventées
    widgets/                     widgets Flutter purs, sans dépendance à GenUI
```

### La boucle agent

```
texte ou voix du patient / toucher sur un widget
        │
        ▼
Conversation ──► A2uiTransportAdapter.onSend ──► Gemini (streaming)
                                                     │ JSON A2UI
                                                     ▼
Surface ◄── SurfaceController ◄── transport.addChunk(texte)
   │
   └── dispatchEvent(UserActionEvent) ─► controller.onSubmit ─► Conversation ─► Gemini
```

Chaque tour reçoit un `surfaceId` unique (`triage-1`, `triage-2`…). L'écran fait un fondu vers la dernière surface : chaque nouvelle interface se voit depuis le fond de la salle.

### Garde-fous

- **JSON Schema** sur chaque CatalogItem (`enumValues`, `minimum`/`maximum`, `required`) : genui valide chaque composant généré.
- **Garde Dart** (`strictProps`) : genui laisse passer les propriétés inconnues, Dart les rejette et le dit à l'agent.
- **Auto-correction** : quand une interface est refusée, l'erreur est renvoyée à Gemini, qui corrige (2 tentatives au plus).
- **Test de non-régression** : `test/pipeline_test.dart` extrait les 14 exemples du prompt et les fait passer dans le vrai pipeline. Si le prompt et le catalogue divergent, le test échoue.

---

## Le catalogue

| Composant | Rôle | Événement renvoyé à l'agent |
|---|---|---|
| `InfoCard` | Empathie, conseil. Toujours en premier | Aucun |
| `SymptomChecker` | Checklist oui/non de symptômes liés | `symptoms_confirmed` `{confirmed, denied}` |
| `TriageForm` | Intensité 1–5, durée, zone du corps, symptômes (pré-remplis) | `triage_submitted` |
| `VitalInput` | Température, fréquence cardiaque | `vitals_submitted` |
| `UrgencyCard` | Verdict vert / orange / rouge, action, délai | Aucun |
| `ActionButtons` | La suite, appel des urgences en rouge | `action_selected` `{actionId, label}` |
| `PictoChoice` | Grands pictogrammes pour un patient qui ne lit pas : un toucher répond | `picto_selected` `{id, label}` |

Les pictogrammes (`fever`, `chest_pain`, `child`, `bleeding`...) sont une enum : l'agent écrit un nom, Flutter choisit l'image et la couleur.

L'agent combine ces 7 composants avec **18 composants de [genui_catalog](https://pub.dev/packages/genui_catalog)** dans la même interface : `StepperCard`, `ListCard`, `MediaCard`, `StatusBadge`, `KpiCard`, `StatRow`, `ChartCard`, `DataTable`, `TimelineCard`, `ProfileCard`, `ActionForm`, `SelectInput`, `CheckboxGroup`, `SwitchGroup`, `RatingInput`, `EmptyState`, `Column`, `Row`. Seul `SearchBar` est écarté (un appel au LLM par frappe). Les libellés du package sont fixés en français par le prompt (`requiredErrorText`, `noRatingLabel`...).

## Trois niveaux, un seul catalogue

1. **En ligne** : Gemini comprend et compose l'interface (A2UI).
2. **Hors-ligne** : Gemma 4 E2B, sur le GPU du téléphone, comprend seulement. Il remplit trois champs (`symptom`, `alarm`, `summary`) dans un schéma JSON, Dart les vérifie et compose l'écran. La carte « J'ai compris » redit au patient ce qui a été entendu.
3. **Sans modèle** : des règles reconnaissent les signes d'alarme et quelques mots-clés en français (avec ou sans accents), et demandent avec des pictogrammes quand elles ne comprennent pas.

Les appels (urgences, clinique) passent toujours : le GSM n'est pas internet. Le bandeau « Hors-ligne · Gemma sur ce téléphone » (ou « Hors-ligne · règles sur l'appareil, sans IA ») dit qui a composé l'écran.

Pour la scène : menu ⋯ → **Simuler une coupure réseau**. Le modèle se télécharge une fois dans menu ⋯ → **IA sur l'appareil (Gemma)** (2,6 Go, en Wi-Fi), jusqu'à l'état « Prêt, hors-ligne ».

Les erreurs de configuration (Firebase AI Logic désactivé, région non supportée) ne basculent pas en hors-ligne : elles s'affichent.

## Agentic Hot Reload (Flutter 3.44+)

1. `fvm flutter run -d <id> --print-dtd --dart-define-from-file=.env.json`
2. L'agent utilise le serveur MCP `dart` : [`.mcp.json`](.mcp.json) pour Claude Code (`fvm dart mcp-server`).
3. Demandez un changement : l'agent appelle `hot_reload`, `get_runtime_errors`, `widget_inspector`.

Démo de la keynote : ajouter un grand pictogramme à `UrgencyCard`. Le résultat attendu est dans [`demo/urgency_pictogram.patch`](demo/urgency_pictogram.patch) (secours : `git apply demo/urgency_pictogram.patch`, puis `r`).

## Scénarios (menu ⋯ ou exemples de l'écran vide)

1. « J'ai de la fièvre et des maux de tête depuis 3 jours » → `InfoCard` + `SymptomChecker`, puis carte orange (test du paludisme).
2. « J'ai une forte douleur dans la poitrine et j'ai du mal à respirer » → carte rouge qui pulse + **Appeler les urgences**.
3. « J'ai mal à la tête » → `TriageForm` pré-rempli.
4. « Je ne sais pas bien lire » → `PictoChoice` (Fièvre, Tête, Poitrine, Ventre, Mon enfant, Sang).

Le bouton ✎ **Nouvelle consultation** repart d'un écran vide.

À la voix : « J'ai de la fièvre depuis trois jours ». Aucune transcription locale : Gemini écoute l'audio, et l'`InfoCard` redit ce qu'il a compris.

Hors-ligne : « Mon bébé a de la fièvre depuis hier » → question sur l'âge de l'enfant → « Moins de 3 mois » → carte rouge + appel des urgences. Le pictogramme « Poitrine » mène aussi à la carte rouge.

### Conseils pour le live

- Faites tourner les scénarios juste avant de monter sur scène : une première requête « froide » est plus lente.
- Téléchargez Gemma en Wi-Fi avant la keynote, et vérifiez l'état « Prêt, hors-ligne ».
- Les polices viennent de Google Fonts au runtime. Hors-ligne, [embarquez-les dans les assets](https://pub.dev/packages/google_fonts#bundling-fonts-when-releasing).
- Testez le micro dans la salle : parlez près du téléphone.
- Enregistrez une vidéo de secours de la démo.

---

Omar Farouk KOUGBADA · GDE Flutter & Dart · [@OKougbada](https://x.com/OKougbada) · [pub.dev/packages/genui_catalog](https://pub.dev/packages/genui_catalog)
