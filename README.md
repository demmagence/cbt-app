# CBT App - Computer Based Test Application

CBT App is a Flutter-based mobile application integrated with Firebase, designed for conducting highly secure examinations. The application incorporates native anti-cheat mechanisms, offline resiliency, and distinct portals for Administrators, Teachers, and Students.

## Key Features

### 1. Security and Anti-Cheat System
* **Fullscreen Immersive Sticky Mode**: Restricts user navigation by locking the application interface in full-screen mode to prevent access to system settings, notifications, or other device resources.
* **Screenshot and Screen Recording Prevention**: Utilizes native platform channels (`FLAG_SECURE` on Android) to block screen captures and render video recordings black.
* **App Switch Detection**: Monitors and logs instances of the application losing focus (e.g., system alerts, phone calls, or switching applications). Each event, including its timestamp and duration in seconds, is recorded to the database for evaluation.
* **Offline Resiliency**: Detects network connectivity changes in real-time, displays status banners, and ensures exam data is cached locally and synchronized with the remote database once connectivity is restored.

### 2. Role-Based Access Control
* **Administrator Portal**:
  * System-wide statistics and analytical dashboard.
  * User account management (Create, Read, Update, Delete operations; activation and deactivation of Teacher and Student accounts).
* **Teacher Portal**:
  * Question bank management and exam creation tools.
  * Automated randomization of questions and multiple-choice options per student.
  * Real-time monitoring dashboard to track student exam progress and log focus-lost violations.
  * Manual evaluation interface for essay questions, including written feedback.
  * Data export capabilities for exam results in CSV format.
* **Student Portal**:
  * Exam registration via unique 6-character schedules/tokens.
  * Interactive exam interface with auto-save capabilities.
  * History log of completed exams and scores post-evaluation.

## Technical Stack

* **Framework**: Flutter (Android and iOS)
* **Language**: Dart
* **State Management**: BLoC and Cubit (via `package:flutter_bloc`)
* **Backend Services**:
  * **Authentication**: Firebase Authentication (Session management)
  * **Database**: Cloud Firestore (utilizing the non-default database instance `cbt-db`)
* **Key Dependencies**:
  * `equatable`: State comparison
  * `share_plus` & `csv`: Grade report exports
  * `intl`: Date and time localization
  * `mocktail` & `integration_test`: Automated testing frameworks

## Directory Structure

```text
cbt_app/
├── .github/
│   └── PULL_REQUEST_TEMPLATE.md  # Pull request template for code contributions
├── docs/                         # Technical documentation
│   ├── api-services.md           # API and service layer documentation
│   ├── architecture.md           # Data flow and BLoC architecture details
│   ├── bug-fixing-report.md      # End-to-end bug fixing log
│   ├── code-review.md            # Code review guidelines
│   ├── firestore-rules-audit.md  # Firestore security rules audit report
│   └── integration-testing.md    # Guide for integration testing
├── integration_test/             # End-to-end integration tests
│   └── app_test.dart
├── lib/
│   ├── blocs/                    # BLoC/Cubit business logic layers
│   │   ├── admin/
│   │   ├── auth/
│   │   ├── guru/
│   │   └── siswa/
│   ├── config/                   # Navigation routing and theme configurations (Material 3)
│   ├── models/                   # JSON serialization and data models
│   ├── screens/                  # UI screens grouped by roles
│   ├── services/                 # Firebase and native service layer abstractions
│   ├── widgets/                  # Reusable UI widgets
│   ├── app.dart                  # Core MaterialApp and dependency injection setup
│   └── main.dart                 # Application entry point and Firebase initialization
├── test/                         # Unit and widget tests
│   └── app_widget_test.dart
├── firestore.rules               # Cloud Firestore security rules
└── pubspec.yaml                  # Project dependencies and asset definitions
```

## Getting Started

### Prerequisites
* Flutter SDK (version `>=3.11.0`)
* Firebase CLI

### Installation and Setup

1. **Clone the Repository**:
   ```bash
   git clone https://github.com/demmagence/cbt-app.git
   cd cbt-app
   ```

2. **Retrieve Dependencies**:
   ```bash
   flutter pub get
   ```

3. **Configure Firebase**:
   * Initialize the Firebase project in your local workspace:
     ```bash
     flutterfire configure
     ```
   * Enable **Email/Password Authentication** and **Cloud Firestore** in the Firebase Console.
   * *Note*: The application relies on a non-default database instance named `cbt-db`. Ensure you provision this specific database ID in your Firestore console before running the app.

4. **Deploy Security Rules**:
   Deploy the `firestore.rules` file to your Firebase console:
   ```bash
   firebase deploy --only firestore:rules
   ```

5. **Run the Application**:
   Connect an Android or iOS device (or start an emulator) and execute:
   ```bash
   flutter run
   ```

## Quality Assurance and Testing

To maintain code quality and stability, ensure all changes pass the following validation steps:

### Static Analysis
Run the linter to verify formatting and detect code issues:
```bash
flutter analyze
```

### Unit and Widget Testing
Execute the suite of unit and widget tests:
```bash
flutter test
```

### Integration Testing
Execute automated end-to-end integration tests on a connected device:
```bash
flutter test integration_test/app_test.dart
```

## Contribution Guidelines

* All new features or bug fixes must be developed on separate branches (e.g., `feature/feature-name` or `bugfix/issue-name`).
* Submit a Pull Request (PR) utilizing the provided template.
* Refer to [docs/code-review.md](file:///c:/Users/wibis/Documents/Code/Project/cbt_app/docs/code-review.md) for detailed code review criteria.

## License
Internal project license. Copyright © 2026. All rights reserved.
