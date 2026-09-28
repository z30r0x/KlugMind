# KlugMind — AI Study Planner & Active Recall Engine

> Turn any syllabus or note set (text, PDF, or photo) into a realistic daily study plan, auto-generated active recall practice, and adaptive spaced repetition schedules.

---

## 📌 Project Overview

**KlugMind** solves a widespread friction point for students: wasting hours manually translating dense syllabi into calendar items and relying on passive re-reading to study. 

By combining optical character recognition (OCR), structured LLM processing, and the **SuperMemo-2 (SM-2)** algorithm, KlugMind turns raw academic input into:
1. **Dynamic Daily Schedules** with priority scoring and one-tap re-planning when life happens.
2. **Interactive Flashcards & Quizzes** generated instantly from notes with automated spaced-repetition tracking.

Built for high school, university, and certification students managing heavy reading loads across multiple courses.

---

## ✨ Key Features

### 📅 Smart Onboarding & Daily Planning
* **Multi-Format Input:** Import material via raw text, PDF upload, or camera photo extraction.
* **Structured Syllabus Parsing:** AI identifies assignments, exams, dates, and grade weightings with an editable preview step before saving.
* **Today's Plan:** Time-blocked tasks prioritized into *Critical*, *High*, *Medium*, and *Low* urgency queues.
* **"I Fell Behind" Dynamic Re-Planning:** Select missed tasks and instantly recalculate the week's workload based on remaining hours and priority weights.

### 🧠 Active Recall & Spaced Repetition Engine
* **Instant Study Kit Generation:** Generate 10 contextual flashcards and a 5-question quiz from any study material.
* **Dart-Native SM-2 Scheduler:** Tracks ease factor, review intervals, and repetition counts offline per card.
* **Focus Mode:** Single-task focus view designed to minimize cognitive load.

---

## 🛠 Tech Stack

* **Frontend & Mobile:** Flutter (Dart) using Material 3 UI design tokens.
* **AI & LLM Services:** Hosted LLMs (Google Gemini API / OpenAI API) with structured JSON enforcement and prompt-fallback handling.
* **OCR Pipeline:** Google ML Kit (Device-based text recognition) with an editable preview layer to fix extraction noise.
* **Backend & Auth:** Supabase / Firebase (Authentication, cloud storage for material files, database).
* **Local Storage & State:** Hive / SharedPreferences for offline scheduling capabilities.

---

## 🏛 System Architecture & Data Flow

```
[ Syllabus / Photo / PDF ]
          │
          ▼
    [ ML Kit OCR ]
          │
          ▼
   [ Editable Text ] ──► [ LLM Service (Structured JSON Mode) ]
                                      │
                                      ▼
                      [ Local Data Store / App State ]
                                   ┌──┴───────────────┐
                                   ▼                  ▼
                         [ SM-2 Scheduler ]   [ Dynamic Planner ]
```

### Core Data Models

* **Course:** `id`, `name`, `color`, `weekly_target_hours`
* **Assignment/Exam:** `id`, `course_id`, `title`, `type`, `due_date`, `weight`, `status`
* **StudyTask:** `id`, `assignment_id`, `planned_date`, `duration_minutes`, `priority`, `is_completed`
* **Material/Note:** `id`, `course_id`, `file_url`, `extracted_text`
* **Flashcard/QuizItem:** `id`, `material_id`, `question`, `answer`, `difficulty`, `next_review_at`, `interval`, `ease_factor`

---

## 🚀 Getting Started & Setup Instructions

Follow these steps to run KlugMind locally on your environment or physical device.

### Prerequisites
* [Flutter SDK](https://docs.flutter.dev/get-started/install) (v3.19.0 or higher recommended)
* [Dart SDK](https://dart.dev/get-dart)
* Android Studio / Xcode (for device emulators)
* A Gemini API key (or OpenAI/Groq API key)

### 1. Clone the Repository
```bash
git clone https://github.com/your-username/klugmind.git
cd klugmind
```

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Configure Environment Variables
Copy the provided `.env.example` file to create your local `.env` configuration:

```bash
cp .env.example .env
```

Open `.env` and insert your credentials:
```env
GEMINI_API_KEY=your_gemini_api_key_here
SUPABASE_URL=your_supabase_project_url
SUPABASE_ANON_KEY=your_supabase_anon_key
```

### 4. Run the Application
Connect an Android/iOS emulator or physical device, then run:

```bash
flutter run
```

---

## 💡 Hackathon Learning & Technical Achievements

* **Structured LLM Parsing:** Designed strict JSON schemas for syllabus extraction, reducing JSON parse errors from ~20% during early prompts to under 1.5% using schema enforcement and fallback repair layers.
* **SM-2 Engine Implementation:** Wrote a fully offline-first Dart implementation of the SM-2 spaced repetition algorithm, ensuring students can perform active recall reviews even without an active internet connection.
* **OCR Reliability:** Implemented an interactive preview state following ML Kit text extraction, allowing users to verify dates and weights prior to database commit.
* **Dynamic Re-planning Algorithm:** Solved schedule overflow issues by calculating priority ratios based on target weights and remaining days until deadline.

---

## 📜 License

Distributed under the MIT License. See `LICENSE` for more information.