# Trivia Showdown

**Author:** Jamal Lyons

CSC 4360 In-Class Activity 15, API-to-Cloud Trivia Showdown. The app fetches five easy multiple-choice General Knowledge questions, shows loading and failure as their own screens, scores one answer per question, and then offers a clearly labeled score sync.

## What it does

- Requests five questions from the Open Trivia Database and will not start a round unless the HTTP status is 200 and the API `response_code` is 0.
- Decodes HTML entities in the question and every answer before they are shown (`&quot;`, `&#039;`, `&amp;`, and the rest of the named and numeric references).
- Shuffles the combined correct and incorrect answers.
- Shows a progress indicator while the request is in flight, and a readable error with **Try again** when the request times out, cannot connect, returns another HTTP status, or comes back with a non-zero `response_code` or an empty `results` list. A failed response is never shown as a round.
- Accepts one answer per question. The correct option turns green. A wrong pick turns red and the correct option is still shown in green. Later taps do not change the score.
- Shows the score out of the number of questions that actually loaded, then **Play again** (a new fetch) and **Sync Score to Leaderboard**.

## Setup and run

Install the current stable Flutter SDK, then from this directory:

```bash
flutter pub get
flutter run
```

On Chrome:

```bash
flutter run -d chrome
```

The Android manifest includes `INTERNET` so a device build can reach the API. iOS allows this HTTPS endpoint with the default App Transport Security settings.

Material widgets are imported from `package:material_ui/material_ui.dart`. That is the import `flutter create` writes on Flutter 3.50.0 stable, the SDK current for this activity (Dart 3.14.0).

Check the project before submitting:

```bash
flutter analyze
flutter test
```

`flutter analyze` reports no issues. `flutter test` covers entity decoding, question mapping, API parsing and error handling with a mocked HTTP client, the one-answer score flow, and the loading, error, and success screens.

## API

```
GET https://opentdb.com/api.php?amount=5&category=9&difficulty=easy&type=multiple
```

The client waits at most 10 seconds. It checks the HTTP status before it reads `results`. Only `response_code == 0` with a non-empty `results` array becomes questions. An HTTP 200 with `response_code` 1, 2, 3, or 4 is still an error (`Trivia API did not return questions.`). An empty list is `No questions were returned.`

`Question.fromJson` maps each result to `questionText`, `correctAnswer`, and shuffled `options`, and decodes entities in all of that text. Extra fields such as `category` and `difficulty` are ignored. The screen labels the round General Knowledge / Easy because that is what this fixed request asks for.

## Score sync

No instructor endpoint was provided, so the default action is the classroom simulation.

- The button label is **Sync Score to Leaderboard**.
- The results card is titled **Classroom simulation** and says that no request is sent.
- `_syncScoreToCloud` waits about 1.2 seconds, marks the score synced, and shows a snackbar: `Simulation only: score N of M was not sent to a server.`
- That path does not call the HTTP client. Nothing is written to a server. The confirmation is not remote persistence.
- The button is disabled after a successful simulation so it cannot be presented as several writes.

A real write is used only when an endpoint is supplied at build time:

```bash
flutter run --dart-define=SCORE_ENDPOINT=https://instructor.example/leaderboard
```

That build POSTs JSON:

```json
{"score": 3, "total": 5}
```

Success is shown only after an HTTP 2xx response (`Score N of M was saved to the leaderboard.`). A timeout, a connection failure, or any other status leaves the button enabled and shows a failure snackbar. The score is not described as saved.

## Screenshots

Taken November 12, 2026 from the Flutter web release build, in a 390×960 viewport. The question, answer, and score images are one unmodified Open Trivia Database round. The browser sent `GET https://opentdb.com/api.php?amount=5&category=9&difficulty=easy&type=multiple` and got HTTP 200. Loading was captured while that response was still in flight. The error screen is a separate load whose connection to `opentdb.com` was refused.

| Image | What it shows |
| --- | --- |
| [Loading](docs/screenshots/01-loading.png) | Progress indicator while the five-question request is in flight. No question is shown yet. |
| [Error](docs/screenshots/02-error.png) | A refused connection. The message is readable, the round is not created, and **Try again** is available. |
| [Question](docs/screenshots/03-question.png) | Live question 1 of 5, score 0, shuffled choices 10, 9, 7, 8. **Continue** stays disabled. |
| [Correct](docs/screenshots/04-correct.png) | Question 2. Soviet Union is green, with a check icon. Score becomes 1. |
| [Incorrect](docs/screenshots/05-incorrect.png) | Question 1. 8 is red. 7, the correct answer, is green. The score stays 0. |
| [Final score](docs/screenshots/06-results-sync.png) | 3 out of 5, the simulation card and payload, the sync button disabled, and the snackbar that says the score was not sent. |
| [Decoded text](docs/screenshots/07-live-round.png) | Question 3 of the same live round. The API sent `Papa John&#039;s`; the screen shows Papa John's. Score is still 1, and the choices are neutral again. |

![Loading](docs/screenshots/01-loading.png)

![Could not load the round](docs/screenshots/02-error.png)

![Live question 1 of 5](docs/screenshots/03-question.png)

![Correct answer in green](docs/screenshots/04-correct.png)

![Incorrect answer in red and the correct answer in green](docs/screenshots/05-incorrect.png)

![Final score and the simulation snackbar](docs/screenshots/06-results-sync.png)

![Question 3 with the apostrophe decoded](docs/screenshots/07-live-round.png)

Expected and observed: loading shows the indicator and no question; a refused connection shows the error copy instead of an empty quiz; the live prompt and four shuffled options appear as Question 1 of 5; a correct answer adds one point and turns green; a wrong answer turns red, reveals the green correct option, and does not add a point; question 3 shows the apostrophe decoded from `&#039;`, with the score carried forward and the answer state cleared; the finished round shows 3 out of 5 with replay and the simulation snackbar. The simulation text says the score was not sent. No backend request was sent.

## Project layout

- `lib/services/trivia_api.dart` — GET, timeout, HTTP status, `response_code`, and JSON parsing
- `lib/services/html_entities.dart` — entity decoding
- `lib/services/score_sync.dart` — simulation, or POST when `SCORE_ENDPOINT` is set
- `lib/models/question.dart` — `Question.fromJson`
- `lib/state/trivia_round.dart` — one answer, score, and progression
- `lib/screens/trivia_screen.dart` — `_loadTriviaData`, `_answerQuestion`, `_nextQuestion`, `_syncScoreToCloud`

The screen still owns those four methods. The services exist so the request and the score action can be tested without a widget, which is the split the activity describes as a natural extension.

## Notes for review

HTTP 200 only means the response arrived. `response_code` says whether `results` is a usable question list. Both are checked, in that order.

The simulated sync is a local delay plus a snackbar. It is labeled on the card and in the snackbar. It is not a cloud write. A leaderboard POST would be a different method, URL, and response check; that path runs only when `SCORE_ENDPOINT` is set, and a non-2xx response is shown as a failure.

Answer feedback uses a check or an X along with green and red, so the result is not carried by color alone. Replay always fetches again and resets the score. If that fetch fails, the error screen replaces the old round rather than pretending the old questions are a new live set.

Local storage and Firebase are not part of this activity and are not implemented.

## Looking ahead to In-Class 16

This app reads with `GET` and, only when an endpoint is configured, writes with `POST`. A direct REST route in the next activity would still need a method, a URL, a JSON body, and a status check before the UI claims success. The simulation is the stand-in for that write: the screen already waits, then shows success or failure, but the default path never crosses the network.
