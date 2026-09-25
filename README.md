# Lébénam Triage

> **The End of Static Screens** : application de démo du talk *Building Agentive Flutter Apps with the GenUI SDK*, DevFest Afrique 2026.

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

```bash
flutter pub get
cp .env.example.json .env.json   # puis collez votre clé dans .env.json
flutter run --dart-define-from-file=.env.json
```

- Clé gratuite : <https://aistudio.google.com/apikey>
- Micro : l'autorisation est demandée au premier appui (Android, iOS et macOS sont configurés).
- `.env.json` est ignoré par git : la clé ne part jamais sur GitHub. Sans fichier, `flutter run --dart-define=GEMINI_API_KEY=votre_clé` marche aussi.
- Sans clé au lancement, l'app affiche un écran pour coller la clé, qui est ensuite enregistrée sur l'appareil. Pratique sur scène. Menu ⋮ → *Changer la clé API* pour la remplacer.
- Changer de modèle : `GEMINI_MODEL` dans `.env.json` (ex. `gemini-3.5-flash-lite`). Le modèle par défaut est `gemini-3.8-flash`.

```bash
flutter test      # rejoue les exemples du prompt dans le vrai pipeline genui, sans LLM
flutter analyze
```

> **Production** : ne mettez jamais de clé dans une app publiée. Passez par **Firebase AI Logic** (clé côté serveur + App Check).

---

## Architecture

```
lib/
  main.dart                      charge la clé et le thème puis runApp
  app.dart                       MaterialApp, thèmes clair/sombre/système
  core/
    brand/                       logo Lébénam (tracés SVG, version animée)
    config/api_key_store.dart    .env.json / --dart-define ou clé saisie
    constants/prompts.dart       system prompt + exemples few-shot
    theme/                       charte Lébénam (crème, marine, bleu, orange), choix du thème
  features/
    splash/splash_screen.dart    le logo se dessine, puis l'accueil
    home/home_screen.dart        accroche + CTA
    setup/api_key_screen.dart    saisie de la clé (fallback)
    triage/
      triage_agent.dart          ★ la boucle agent GenUI ↔ Gemini (texte + audio)
      triage_screen.dart         Surface GenUI + barre de saisie en bas
      voice/                     enregistrement micro → WAV
      widgets/                   barre de saisie, chargement, état vide
  catalog/
    catalog_items.dart           ★ le contrat LLM ↔ Flutter (6 items maison + 18 genui_catalog)
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

L'agent combine ces 6 composants métier avec **18 composants de [genui_catalog](https://pub.dev/packages/genui_catalog)**, dans la même interface :

| Composant genui_catalog | Usage dans Lébénam |
|---|---|
| `Column`, `Row` | Mise en page (racine, badges côte à côte) |
| `StepperCard` | Étape en cours de la prise en charge (appel, secours en route...) |
| `ListCard`, `MediaCard` | Gestes et conseils, fiche de prévention |
| `StatusBadge` | « Secours appelés », « Ne restez pas seul » |
| `KpiCard`, `StatRow` | Température mise en avant, résumé des réponses |
| `ChartCard` | Évolution de la fièvre sur plusieurs jours |
| `DataTable`, `TimelineCard`, `ProfileCard` | Fiche de triage à montrer à l'accueil |
| `ActionForm` | Prénom, âge, téléphone pour préparer la venue |
| `SelectInput` | Âge d'un enfant (la fièvre avant 3 mois est une alarme) |
| `CheckboxGroup` | Antécédents (grossesse, drépanocytose, diabète...), validés en une fois |
| `SwitchGroup` | Suivi : rappel par SMS, partage de la fiche |
| `RatingInput` | « Cette aide vous a-t-elle été utile ? » |
| `EmptyState` | Demande sans rapport avec la santé |

```dart
import 'package:genui_catalog/genui_catalog.dart' as kit;

final triageCatalog = Catalog([
  infoCardItem, urgencyCardItem, /* ... */
  kit.columnItem, kit.stepperCardItem, kit.listCardItem, /* ... */
], catalogId: 'lebenam_triage');
```

Seul `SearchBar` est écarté (un événement, donc un appel au LLM, par frappe). `CheckboxGroup` et `SwitchGroup` sont utilisés avec `submitLabel` (genui_catalog 0.5.0) : un seul appel par réponse, pas par case. Les boutons Précédent / Suivant du `StepperCard` restent locaux : ils ne relancent pas l'agent. Les libellés du package sont passés en français par le prompt (`requiredErrorText`, `noRatingLabel`...).

Le prompt contient 13 exemples, et `flutter test` les fait tous passer dans le vrai pipeline genui, composants genui_catalog compris.
---

## Déroulé de la démo (sur scène)

Les **exemples** de l'écran vide (ou le menu ⋯) pré-remplissent le champ : il ne reste qu'à appuyer sur Envoyer.

1. « J'ai de la fièvre et des maux de tête depuis 3 jours » → animation de réflexion.
2. L'agent compose **InfoCard** (empathie) + **SymptomChecker**.
3. Cocher 2 symptômes → *Valider*.
4. Nouvelle interface : **UrgencyCard orange** (suspicion de paludisme, test rapide) + **ActionButtons**.
5. « Regardez ce qui se passe avec une douleur thoracique » → ✎ *Nouvelle consultation*, puis scénario *Douleur thoracique*.
6. Interface totalement différente : **UrgencyCard rouge** qui pulse + bouton **Appeler les urgences**.

Le 3ᵉ scénario (« J'ai mal à la tête », volontairement vague) montre le **TriageForm** pré-rempli.

**Bonus micro** : appuyez sur le micro et décrivez vos symptômes à voix haute (en français ou en éwé, mina...). Aucune transcription locale : Gemini écoute l'audio, et l'InfoCard reformule ce qu'il a compris.

L'icône en haut à droite bascule entre les thèmes **clair**, **sombre** et **système**.

### Conseils pour le live

- Faites tourner les 3 scénarios juste avant de monter sur scène : une première requête « froide » est plus lente.
- Comptez quelques secondes par tour avec `gemini-3.8-flash`. L'animation de chargement occupe ce temps.
- Les polices viennent de Google Fonts au runtime. Hors-ligne, [embarquez-les dans les assets](https://pub.dev/packages/google_fonts#bundling-fonts-when-releasing).
- Testez le micro dans la salle : parlez près du téléphone. Si le son est trop faible, l'agent demande de répéter.
- Enregistrez une vidéo de secours de la démo.

---

Omar Farouk KOUGBADA · GDE Flutter & Dart · [@OKougbada](https://x.com/OKougbada) · [pub.dev/packages/genui_catalog](https://pub.dev/packages/genui_catalog)
