# Lébénam Triage

> Application de démo des talks *Building Agentive Flutter Apps with the GenUI SDK* (DevFest Afrique 2026), *Dart as a Security Layer* (DevFest Ajah 2026) et de la keynote **Flutter in the Agentic Era: From West African Clinics to Toyota RAV4** (DevFest Tamale 2026).

Un assistant de triage médical pour les cliniques à faible connectivité en Afrique de l'Ouest. Le patient décrit ses symptômes par écrit ou **à voix haute** (Gemini écoute l'audio directement, y compris en langue locale), et **Gemini compose l'interface Flutter à la volée** à partir d'un catalogue de widgets. Aucun écran de triage n'est codé en dur et il n'y a pas de pile de navigation : chaque réponse de l'agent est une nouvelle interface.

⚠️ Démonstration technique : ne remplace pas un avis médical.

---

## Stack

| Package | Rôle |
|---|---|
| [`genui`](https://pub.dev/packages/genui) `^0.10.3` | SDK GenUI : `SurfaceController`, `Conversation`, `Surface`, protocole A2UI |
| [`genui_catalog`](https://pub.dev/packages/genui_catalog) `^0.5.0` | 18 CatalogItems prêts à l'emploi, combinés aux composants de triage |
| [`google_generative_ai`](https://pub.dev/packages/google_generative_ai) | Appel à Gemini en streaming |
| `json_schema_builder` | Schémas JSON des CatalogItems |
| `record` | Message vocal : micro en PCM 16 kHz mono, envoyé à Gemini en WAV |
| `google_fonts`, `flutter_animate`, `gap`, `flutter_svg` | Design (charte Lébénam : Newsreader, Hanken Grotesk, Rochester), logo animé |
| `flutter_launcher_icons`, `flutter_native_splash` *(dev)* | Icône de l'app et écran de lancement natif |

> `genui_google_generative_ai` est **discontinué** et bloqué à genui 0.7. L'app branche donc Gemini elle-même via `A2uiTransportAdapter` (voir [`triage_agent.dart`](lib/features/triage/triage_agent.dart)). Ça tient en une trentaine de lignes.

---

## Lancer l'app

Aucune clé Gemini dans l'app : les requêtes passent par **Firebase AI Logic** (la clé reste côté serveur) et **App Check** prouve qu'elles viennent de l'app.

Le projet est épinglé sur **Flutter 3.47.9** avec [fvm](https://fvm.app) (`.fvmrc`) : Agentic Hot Reload demande Dart 3.12 ou plus.

```bash
fvm install                      # une fois
fvm flutter pub get
cp .env.example.json .env.json   # numéros de téléphone, modèle
fvm flutter run --dart-define-from-file=.env.json
```

- Firebase : projet `lebenamtriage`, configuré avec `flutterfire configure --project=lebenamtriage`. Dans la console, activez **Firebase AI Logic** (Gemini Developer API).
- App Check : en debug, l'app utilise `APP_CHECK_DEBUG_TOKEN` de `.env.json` (un UUID). Enregistrez-le dans Firebase → App Check → *Apps* → ⋮ → *Gérer les jetons de débogage*, pour chaque app (Android, Apple). Le web n'active pas App Check (il faudrait une clé reCAPTCHA).
- macOS : App Check a besoin du partage de trousseau, donc d'une app signée avec une équipe Apple. Non configuré ici : la démo tourne sur Android.
- Micro : l'autorisation est demandée au premier appui (Android, iOS et macOS sont configurés).
- Changer de modèle : `GEMINI_MODEL` dans `.env.json` (ex. `gemini-3.5-flash-lite`). Le modèle par défaut est `gemini-3.8-flash`.

```bash
flutter test      # rejoue les exemples du prompt dans le vrai pipeline genui, sans LLM
flutter analyze
```

---

## Architecture

```
lib/
  main.dart                      Firebase + App Check, thème, puis runApp
  app.dart                       MaterialApp, thèmes clair/sombre/système
  core/
    brand/                       logo Lébénam (tracés SVG, version animée)
    config/gemini_config.dart    modèle Gemini (aucune clé)
    constants/prompts.dart       system prompt + exemples few-shot
    theme/                       charte Lébénam (crème, marine, bleu, orange), choix du thème
  features/
    splash/splash_screen.dart    le logo se dessine, puis l'accueil
    home/home_screen.dart        accroche + CTA
    triage/
      triage_agent.dart          ★ la boucle agent GenUI ↔ Gemini (texte + audio), repli hors-ligne
      offline/offline_triage.dart  règles locales : même protocole A2UI, même catalogue, sans IA
      triage_screen.dart         Surface GenUI + barre de saisie en bas
      voice/                     enregistrement micro → WAV
      widgets/                   barre de saisie, chargement, état vide
  catalog/
    catalog_items.dart           ★ le contrat LLM ↔ Flutter (7 items maison + 18 genui_catalog)
    widgets/                     widgets Flutter purs, sans dépendance à GenUI
```

### La boucle agent

```
texte du patient / tap sur un widget
        │
        ▼
Conversation ──► A2uiTransportAdapter.onSend ──► Gemini (streaming)
                                                     │ JSON A2UI
                                                     ▼
Surface ◄── SurfaceController ◄── transport.addChunk(texte)
   │
   └── dispatchEvent(UserActionEvent) ─► controller.onSubmit ─► Conversation ─► Gemini
```

1. **`SurfaceController`** connaît le catalogue et gère les surfaces.
2. **`A2uiTransportAdapter`** est le tuyau vers le LLM. Le texte streamé par Gemini est poussé avec `addChunk`, et le parser de genui extrait les messages A2UI (`createSurface`, `updateComponents`) au fil de l'eau.
3. **`Conversation`** relie les deux. Les messages A2UI vont au controller, et les événements des widgets repartent vers le LLM comme un nouveau tour.
4. **`PromptBuilder.chat`** assemble le prompt métier, les règles du protocole A2UI et le JSON Schema de chaque CatalogItem.
5. **`Surface`** rend l'arbre de widgets composé par l'agent.

Chaque tour reçoit un `surfaceId` unique (`triage-1`, `triage-2`…). L'écran fait un fondu vers la dernière surface, ce qui rend chaque nouvelle interface très visible pour le public.

### Garde-fous

- **JSON Schema strict** sur chaque CatalogItem (`enumValues`, `minimum`/`maximum`, `required`). genui valide chaque composant généré.
- **Auto-correction** : quand genui rejette un JSON (composant inventé, prop invalide), l'erreur est renvoyée à Gemini, qui corrige. C'est limité à 2 tentatives par demande.
- **Parsing tolérant** côté Flutter : une valeur inconnue (`"level": "orange"`) retombe sur un défaut au lieu de planter.
- **Test de non-régression** : `test/pipeline_test.dart` extrait les exemples du system prompt et les fait passer dans le vrai pipeline. Si le prompt et le catalogue divergent, le test échoue.

---

## Le catalogue

| Composant | Rôle | Événement renvoyé à l'agent |
|---|---|---|
| `InfoCard` | Empathie, conseil. Toujours en premier | Aucun |
| `SymptomChecker` | Checklist oui/non + progression | `symptoms_confirmed` `{confirmed, denied}` |
| `TriageForm` | Intensité 1–5, durée, zone du corps, symptômes (pré-remplis) | `triage_submitted` |
| `VitalInput` | Température, fréquence cardiaque | `vitals_submitted` |
| `UrgencyCard` | Verdict vert / orange / rouge, action, délai | Aucun |
| `ActionButtons` | Prochaines étapes, appel d'urgence en rouge | `action_selected` `{actionId, label}` |
| `PictoChoice` | Grands pictogrammes pour un patient qui ne lit pas : un toucher répond | `picto_selected` `{id, label}` |

### Ajouter un composant

1. **Le widget** : un `StatelessWidget`/`StatefulWidget` Flutter classique dans `lib/catalog/widgets/`, avec des paramètres typés et des callbacks. Il ne connaît pas GenUI.
2. **Le `CatalogItem`** dans `catalog_items.dart` :

   ```dart
   final medicationReminderItem = CatalogItem(
     name: 'MedicationReminder',                 // le mot que le LLM écrit
     dataSchema: S.object(                       // ce qu'il a le droit d'envoyer
       description: 'Rappel de prise de médicament.',
       properties: {
         'drug': S.string(),
         'timesPerDay': S.integer(minimum: 1, maximum: 4),
       },
       required: ['drug', 'timesPerDay'],
     ),
     widgetBuilder: (ctx) {
       final data = (ctx.data as Map).cast<String, Object?>();
       return MedicationReminderWidget(
         drug: data['drug'] as String,
         timesPerDay: (data['timesPerDay'] as num).toInt(),
         onConfirm: () => ctx.dispatchEvent(UserActionEvent(
           name: 'reminder_confirmed',
           sourceComponentId: ctx.id,
         )),
       );
     },
   );
   ```

3. **L'enregistrer** dans la liste `triageCatalog`.
4. **Le décrire** dans `prompts.dart` (quand l'utiliser), avec idéalement un exemple. Le test le validera automatiquement.

L'agent combine ces 7 composants métier avec **18 composants de [genui_catalog](https://pub.dev/packages/genui_catalog)**, dans la même interface :

| Composant genui_catalog | Usage dans Lébénam |
|---|---|
| `Column`, `Row` | Mise en page (racine, badges côte à côte) |
| `StepperCard` | Étape en cours de la prise en charge (appel, secours en route...) |
| `ListCard`, `MediaCard` | Gestes et conseils, fiche de prévention |
| `StatusBadge` | « Help called », « Do not stay alone » |
| `KpiCard`, `StatRow` | Température mise en avant, résumé des réponses |
| `ChartCard` | Évolution de la fièvre sur plusieurs jours |
| `DataTable`, `TimelineCard`, `ProfileCard` | Fiche de triage à montrer à l'accueil |
| `ActionForm` | Prénom, âge, téléphone pour préparer la venue |
| `SelectInput` | Âge d'un enfant (la fièvre avant 3 mois est une alarme) |
| `CheckboxGroup` | Antécédents (grossesse, drépanocytose, diabète...), validés en une fois |
| `SwitchGroup` | Suivi : rappel par SMS, partage de la fiche |
| `RatingInput` | « Was this help useful? » |
| `EmptyState` | Demande sans rapport avec la santé |

```dart
import 'package:genui_catalog/genui_catalog.dart' as kit;

final triageCatalog = Catalog([
  infoCardItem, urgencyCardItem, /* ... */
  kit.columnItem, kit.stepperCardItem, kit.listCardItem, /* ... */
], catalogId: 'lebenam_triage');
```

Seul `SearchBar` est écarté (un événement, donc un appel au LLM, par frappe). `CheckboxGroup` et `SwitchGroup` sont utilisés avec `submitLabel` (genui_catalog 0.5.0) : un seul appel par réponse, pas par case. Les boutons Previous / Next du `StepperCard` restent locaux : ils ne relancent pas l'agent. Les libellés du package sont fixés en anglais par le prompt (`requiredErrorText`, `noRatingLabel`...).

Le prompt contient 14 exemples, et `flutter test` les fait tous passer dans le vrai pipeline genui, composants genui_catalog compris, ainsi que chaque réponse du triage hors-ligne.

---

## Hors-ligne : la clinique continue sans réseau

L'agent n'est pas l'interface : le catalogue l'est. Quand Gemini est injoignable (après une nouvelle tentative, ou 20 s sans réponse), [`OfflineTriage`](lib/features/triage/offline/offline_triage.dart) écrit la réponse A2UI sur l'appareil, avec les mêmes CatalogItems. La `Surface`, les widgets et la garde Dart ne savent pas qui a répondu.

- Ce sont des règles, pas une IA : signes d'alarme et mots-clés clairs (fièvre, enfant...). Sinon, elles demandent avec des pictogrammes (`PictoChoice`).
- Un message vocal hors-ligne ne peut pas être écouté : l'app le dit, et propose les pictogrammes.
- Les appels (urgences, clinique) passent toujours : le GSM n'est pas internet.
- Un bandeau « Offline · on-device triage, no AI » indique qui a composé l'écran.
- Pour la scène : menu ⋯ → **Simulate a network outage** (ou le mode avion du téléphone).
- Les erreurs de configuration (Firebase AI Logic désactivé, région non supportée) ne basculent pas en hors-ligne : elles s'affichent.

## Agentic Hot Reload (Flutter 3.44+)

L'agent de code modifie le code, recharge l'app lancée et lit les erreurs, via le serveur MCP Dart (expérimental).

1. `fvm flutter run --dart-define-from-file=.env.json`
2. L'agent utilise le serveur `dart` : [`.mcp.json`](.mcp.json) pour Claude Code (`fvm dart mcp-server`). Dans Antigravity, ajoutez la même commande.
3. Demandez un changement : l'agent appelle `hot_reload`, `get_runtime_errors`, `widget_inspector`.

Démo de la keynote : ajouter un grand pictogramme à `UrgencyCard`. Le résultat attendu est dans [`demo/urgency_pictogram.patch`](demo/urgency_pictogram.patch) (secours : `git apply demo/urgency_pictogram.patch`, puis `r`).
---

## Déroulé de la démo (sur scène)

Les **exemples** de l'écran vide (ou le menu ⋯) pré-remplissent le champ : il ne reste qu'à appuyer sur Send.

1. « I have had a fever and a headache for 3 days » → animation de réflexion.
2. L'agent compose **InfoCard** (empathie) + **SymptomChecker**.
3. Cocher 2 symptômes → *Send my answers*.
4. Nouvelle interface : **UrgencyCard orange** (suspicion de paludisme, test rapide) + **ActionButtons**.
5. « Regardez ce qui se passe avec une douleur thoracique » → ✎ *New consultation*, puis le 2ᵉ exemple (douleur thoracique).
6. Interface totalement différente : **UrgencyCard rouge** qui pulse + bouton **Call emergency services**.

Le 3ᵉ scénario (« My head hurts », volontairement vague) montre le **TriageForm** pré-rempli.

**Bonus micro** : appuyez sur le micro et décrivez vos symptômes à voix haute (en anglais, en français ou dans une langue locale : dagbani, twi, éwé...). L'interface revient toujours en anglais. Aucune transcription locale : Gemini écoute l'audio, et l'InfoCard reformule ce qu'il a compris.

L'icône en haut à droite bascule entre les thèmes **clair**, **sombre** et **système**.

### Conseils pour le live

- Faites tourner les 3 scénarios juste avant de monter sur scène : une première requête « froide » est plus lente.
- Comptez quelques secondes par tour avec `gemini-3.8-flash`. L'animation de chargement occupe ce temps.
- Les polices viennent de Google Fonts au runtime. Hors-ligne, [embarquez-les dans les assets](https://pub.dev/packages/google_fonts#bundling-fonts-when-releasing).
- Testez le micro dans la salle : parlez près du téléphone. Si le son est trop faible, l'agent demande de répéter.
- Enregistrez une vidéo de secours de la démo.

---

Omar Farouk KOUGBADA · GDE Flutter & Dart · [@OKougbada](https://x.com/OKougbada) · [pub.dev/packages/genui_catalog](https://pub.dev/packages/genui_catalog)
