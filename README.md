# KlugMind — On-Device AI Study Planner & Flashcard Generator

> Turn notes, syllabi, PDFs, and photos into dated study blocks, AI-generated flashcards, and quizzes—using a small language model that runs directly on the device or through a local Ollama server during development.

***

## 📌 Project Overview

**KlugMind** is an offline-first Flutter study assistant designed to reduce the manual work of organizing academic material. Students can paste a syllabus, dictate notes, upload a PDF, scan a document, or capture a photo; KlugMind extracts the content and structures it into useful study outputs.

The application uses OCR, speech-to-text, PDF text extraction, regex-based date recovery, and an LLM pipeline to identify:

- Exams, quizzes, assignments, and projects with due dates
- Suggested study blocks for the appropriate study day
- Flashcards for active recall
- Quiz questions for practice and self-assessment

When material includes dated academic events, KlugMind converts them into prioritized tasks on the **Today’s Plan** screen. When no reliable dates are found, it instead creates a flashcard deck and quiz content from the learning material.

The app is built around local processing: it can use a model downloaded once onto the device through `flutter_gemma`, or connect to a locally running Ollama model for faster development and testing.

***

## ✨ Key Features

### 📝 Notes, Voice, PDFs, and OCR

- Enter notes manually in an editable text field.
- Use voice dictation with `speech_to_text`.
- Append spoken text to existing notes instead of overwriting it.
- Extract text from PDFs using `syncfusion_flutter_pdf`.
- Extract Latin-script text from images using Google ML Kit OCR.
- Display a warning when OCR confidence is low, helping users review potentially inaccurate text before generation.
- Edit extracted material before generating flashcards, quizzes, or study tasks.

### 🤖 AI-Powered Study Generation

- Sends sanitized study material to an LLM and requests structured JSON output.
- Generates:
  - Assignments and dated academic events
  - Flashcards
  - Quiz items
- Validates the LLM JSON response before using it in the app.
- Runs a single repair prompt if the model response is malformed or cannot be parsed.
- Uses a regex-based fallback to recover dates near words such as:
  - `exam`
  - `quiz`
  - `assignment`
  - `project`
  - `midterm`
  - `final`

### 📆 Today’s Plan

- Displays generated study blocks for the selected day.
- Supports date selection through a date picker.
- Shows a progress card for completed and remaining tasks.
- Lets users tap a task to mark it complete.
- Allows manual task creation with:
  - Task title
  - Course selection
  - Study time
  - Priority
  - Voice dictation
- Includes **Focus Mode**, which launches a flashcard study session.

### 🃏 Flashcards and Quiz Practice

- Creates a flashcard deck when notes do not contain reliable dated tasks.
- Saves the generated deck locally when the user selects **Save & Start Studying**.
- Shows a deck overview before beginning study.
- Provides a swipeable flashcard session.
- Supports recall ratings:
  - Again
  - Good
  - Easy
- Displays the generated quiz item count as part of the study result.

### 👤 Profile and Appearance

- Profile page with placeholder study statistics.
- Course overview section.
- Reminder switches.
- Dark mode support.
- Theme toggle button available across app pages.
- Light and dark palette definitions managed through `colors.dart`.

> **Note:** Profile data, reminder switches, and most settings are currently placeholders and are not persisted between sessions.

***

## 🧠 Study Planning Rules

KlugMind turns recognized assignments and deadlines into actionable study blocks using deterministic planning rules in `StudyStore`.

| Rule | Behavior |
|---|---|
| Study day | A task is planned for the day before its due date |
| Due today | A task due today is surfaced today |
| Overdue items | Overdue work is surfaced on today’s plan |
| Exam or project duration | 90 minutes |
| Quiz duration | 45 minutes |
| Other assignment duration | 60 minutes |
| Critical priority | Due in 2 days or fewer |
| High priority | Due in 5 days or fewer |
| Medium priority | Due in 10 days or fewer |
| Low priority | Due after 10 days |
| Grade weight boost | A weight of 20% or more raises priority by one level |
| Undated assignments | Skipped from automatic study-block generation |

For example, if the model identifies a 25%-weighted midterm due in four days, KlugMind classifies it as **Critical** rather than merely High priority because of the grade-weight boost.

***

## 🔄 System Architecture & Data Flow

```text
Typed Text ───────────────┐
Voice Dictation ──────────┤
PDF Text Extraction ──────┤
Photo / Camera OCR ───────┤
                          ▼
                    [ RawMaterial ]
                          ▼
             [ Editable Notes Text Box ]
                          ▼
              [ StudyIntakeService.analyze ]
              • Sanitization
              • Character length limit
              • Regex date-recovery fallback
                          ▼
               [ LlmService.structureMaterial ]
               • Prompt construction
               • JSON validation
               • One repair prompt on failure
                          ▼
                 [ StructuredExtraction ]
                    ┌───────────────┴────────────────┐
                    ▼                                ▼
      [ Dated Assignments / Events ]      [ Flashcards + Quiz Items ]
                    ▼                                ▼
             [ StudyStore ]                  [ FlashcardsPage ]
                    ▼                                ▼
            [ Today’s Plan ]              [ Flashcard Session ]
```

***

## 🤖 LLM Backends

KlugMind supports two LLM execution modes selected automatically by environment variables.

| Condition | Backend | Default Model | Limits |
|---|---|---|---|
| `OLLAMA_BASE_URL` is configured | Ollama over local HTTP | `qwen2.5:3b` | 10 flashcards, 5 quiz items, 12,000 characters |
| `OLLAMA_BASE_URL` is not configured | On-device model through `flutter_gemma` | Configured through `MODEL_URL` | 5 flashcards, 3 quiz items, 1,500 characters, 1,280-token context window, 120-second timeout |

### On-Device Model Mode

The on-device mode downloads the model once when the user first generates study content. This makes the app suitable for offline-first workflows after the initial model download.

The first generation requires an active internet connection because the model file must be downloaded from the configured `MODEL_URL`.

### Local Ollama Development Mode

During development, KlugMind can connect to Ollama running on the same computer.

| Environment | Suggested Ollama URL |
|---|---|
| Android Emulator | `http://10.0.2.2:11434` |
| iOS Simulator | `http://localhost:11434` |
| Physical Device | Computer LAN IP, such as `http://192.168.x.x:11434` |

For a physical device, expose Ollama to the local network:

```bash
OLLAMA_HOST=0.0.0.0 ollama serve
```

Then set `OLLAMA_BASE_URL` in the app’s `.env` file to your computer’s LAN address.

***

## 💾 Local Storage

KlugMind uses `shared_preferences` to store selected study data locally as JSON.

| Data | Persistence Behavior |
|---|---|
| Study tasks | Restored on app launch and saved whenever `StudyStore.tasks` changes |
| Flashcard deck | Saved when the user taps **Save & Start Studying** |
| Flashcard deck course | Saved together with the deck |
| Courses | In-memory only |
| Profile values | In-memory only |
| Settings and switches | In-memory only |

> **Privacy note:** Local storage is currently unencrypted. Store only non-sensitive academic material, such as general notes, public syllabi, and non-confidential course content.

***

## 🛠 Tech Stack

- **Frontend:** Flutter and Dart
- **UI:** Material Design with custom light and dark palettes
- **On-device LLM:** `flutter_gemma`
- **Local development LLM:** Ollama HTTP API
- **Speech-to-Text:** `speech_to_text`
- **OCR:** Google ML Kit Text Recognition for Latin scripts
- **PDF Extraction:** `syncfusion_flutter_pdf`
- **State Management:** Local stores including `StudyStore` and `CourseStore`
- **Local Persistence:** `shared_preferences`
- **Environment Configuration:** `flutter_dotenv`
- **Testing:** Flutter test framework

***

## 📂 Project Structure

```text
lib/
  main.dart
    Application entry point.
    Initializes FlutterGemma, dotenv, LocalStorage, and theming.

  core/
    models/
      material_models.dart
        RawMaterial
        ExtractedAssignment
        GeneratedFlashcard
        GeneratedQuizItem
        StructuredExtraction

    services/
      llm_service.dart
        Prompt construction, Ollama requests, JSON parsing,
        validation, and repair prompting.

      on_device_llm_service.dart
        flutter_gemma implementation for local model inference.

      study_intake_service.dart
        PDF and image intake, text sanitization, character limits,
        LLM backend selection, and regex date recovery.

      voice_service.dart
        OcrService, VoiceService, and TranscriptSession.

      study_store.dart
        Study block generation, task state, duration rules,
        due-date handling, and priority calculations.

      course_store.dart
        In-memory course management.

      local_storage.dart
        shared_preferences persistence for tasks and flashcard decks.

    widgets/
      Bottom navigation
      Top bar
      Step indicators
      Theme controller
      Theme toggle button

    utils/
      styles/
        colors.dart
        fonts.dart

  features/
    home_page/
      Course setup and onboarding flow.

    onboarding_page/
      Today’s Plan screen.

    notes_page/
      Notes entry, voice input, PDF/photo processing,
      and AI generation flow.

    flashcards_page/
      Deck overview and interactive flashcard session.

    profile_page/
      Profile, courses, placeholder statistics, and settings.

test/
  voice_service_test.dart
  local_storage_test.dart
```

***

## 🚀 Getting Started

### Prerequisites

Install the following before running the project:

- [Flutter SDK](https://docs.flutter.dev/get-started/install) with Dart `^3.10.8`
- Android Studio or Xcode
- JDK 17
- Android device, Android emulator, iOS simulator, or physical iPhone
- Android `minSdkVersion` 24 or higher
- Optional: [Ollama](https://ollama.com/) for local model development

The Android project uses:

- Gradle `8.14`
- Android Gradle Plugin `8.9.2`
- Kotlin `2.1.0`

### 1. Clone the Repository

```bash
git clone https://github.com/your-username/klugmind.git
cd klugmind
```

### 2. Install Flutter Dependencies

```bash
flutter pub get
```

### 3. Create the Environment File

Create a `.env` file in the root of the project.

```bash
touch .env
```

Add the on-device model configuration:

```env
MODEL_URL=https://<host>/<model-file>
MODEL_TYPE=qwen
```

Supported model types:

```env
MODEL_TYPE=qwen
```

```env
MODEL_TYPE=gemma
```

### 4. Optional: Configure Ollama for Development

To use a local Ollama model instead of the on-device backend, add:

```env
OLLAMA_BASE_URL=http://10.0.2.2:11434
OLLAMA_MODEL=qwen2.5:3b
```

Start the Ollama service:

```bash
ollama serve
```

Pull the development model if it is not already installed:

```bash
ollama pull qwen2.5:3b
```

### 5. Run the Application

Connect an emulator, simulator, or physical device, then run:

```bash
flutter run
```

### 6. Run Tests

```bash
flutter test
```

### 7. Generate App Icons

```bash
dart run flutter_launcher_icons
```

***

## 🔐 Platform Permissions

### Android

KlugMind requires the following permissions and declarations:

- `INTERNET` for model download and Ollama communication
- `RECORD_AUDIO` for voice dictation
- Speech recognition service query
- `CAMERA` for capturing study material from the camera

The debug manifest includes `INTERNET`, while the profile manifest includes camera-related configuration.

### iOS

The iOS project requires usage descriptions for:

- Microphone access
- Speech recognition
- Camera access
- Photo library access

Add appropriate descriptions in `Info.plist` before building for iOS.

***

## ⚠️ Important Setup Notes

### `.env` Is Required

Although `.env` is listed in `.gitignore`, it is also declared as an asset in `pubspec.yaml`.

That means the Flutter build will fail if the file does not exist. Create a local `.env` file even if you only need placeholder values during early UI development.

Example minimal `.env`:

```env
MODEL_URL=https://example.com/model.bin
MODEL_TYPE=qwen
```

### Keep Secrets Out of `.env`

The `.env` file is bundled into the Flutter application because it is declared as an asset. Do not store API keys, passwords, access tokens, or other secrets in it.

Only use non-sensitive configuration values such as:

- Model URL
- Model type
- Local Ollama URL
- Local model name

***

## 🧪 Current Limitations

- Courses are stored only in memory and are not restored after app restart.
- Profile statistics and reminder controls are placeholders.
- Theme preferences are not persisted.
- OCR currently targets Latin scripts through ML Kit text recognition.
- Generated quiz items are counted but may not yet have a complete dedicated quiz-taking interface.
- Local storage is unencrypted.
- On-device inference is intentionally limited to short input and output sizes to reduce latency and memory pressure.
- The first on-device generation requires internet access to download the model.

***

## 🐛 Known Issues

### Android and iOS Package Identity Mismatch

The application identifiers are not fully consistent:

- Android `applicationId`: `com.example.studypilot`
- iOS bundle identifier: `com.example.studypilot`
- Android namespace and Kotlin package: `com.example.klugmind`

Both `studypilot` and `klugmind` versions of `MainActivity.kt` exist. Before publishing or generating release builds, standardize the app identity across Android and iOS.

### Release Signing

Release builds currently use the debug signing key. Configure a secure production keystore before distributing the application.

### Fonts

`fonts.dart` references **Inter**, but `pubspec.yaml` does not currently define the font assets. Flutter therefore falls back to the default system font, while `main.dart` explicitly uses Roboto in the theme configuration.

To use Inter correctly, add the font files and define them in `pubspec.yaml`.

### Test File Placement

Some `*_test.dart` files are currently located under `lib/`. Flutter only discovers conventional test files inside the root `test/` directory.

Move all tests into:

```text
test/
```

Then run:

```bash
flutter test
```

### Committed Build Reports

Android build report files are currently committed to the repository. Add generated reports and build artifacts to `.gitignore` to keep the repository clean.

Suggested additions:

```gitignore
build/
.dart_tool/
.android/
.idea/
*.iml
android/build/
android/app/build/
android/**/*.html
android/**/reports/
```

***

## 💡 Technical Highlights

- **Offline-first AI workflow:** Supports local model inference on-device after the initial model download.
- **Reliable structured extraction:** Combines JSON validation, a repair prompt, and regex date recovery instead of trusting raw LLM output.
- **Multi-modal study intake:** Handles typed notes, speech-to-text, PDFs, gallery images, and camera photos.
- **Deterministic planning rules:** Converts extracted due dates into predictable study blocks based on urgency, type, and grade weight.
- **Practical fallback behavior:** If notes do not contain dated events, KlugMind still creates useful flashcards and quiz items.
- **Editable input before AI generation:** Users can correct OCR or transcription mistakes before generating study material.
- **Local-first persistence:** Study tasks and saved flashcard decks restore automatically after application restart.

***

## 📜 License

Distributed under the MIT License. See `LICENSE` for more information.
