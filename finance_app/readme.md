# Financial Management System

A cross-platform personal finance management application developed using **Flutter and Firebase**.

The application helps users manage their daily finances by tracking income and expenses, setting monthly budgets, managing savings goals and debts, analysing spending patterns, and viewing their overall financial health.

This project was developed as my **Final Year Project (FYP)** for BSc (Hons) Information Technology with a specialism in Financial Technology (FinTech).

## Features

* Income and expense tracking
* Transaction categorisation
* Monthly budget management
* Savings goal tracking
* Debt management
* Financial dashboard
* Financial health score
* Spending and financial analytics
* Invisible expense detection
* Zero-based leftover allocation
* AI financial assistant
* Real-time currency conversion
* Custom CSV and PDF report export
* Email and Google authentication
* Mobile and web support

## Tech Stack

* **Flutter** — Cross-platform application development
* **Dart** — Main programming language
* **Firebase Authentication** — User authentication
* **Cloud Firestore** — Database and financial data storage
* **Firebase Cloud Functions** — Backend functions
* **REST API** — External API integration
* **Git & GitHub** — Version control

## Project Structure

```text
finance_app/
├── lib/
│   ├── core/
│   ├── models/
│   ├── providers/
│   ├── screens/
│   ├── services/
│   ├── widgets/
│   └── main.dart
├── assets/
├── android/
├── web/
├── pubspec.yaml
└── README.md
```

## Main Modules

### Dashboard

Provides an overview of the user's financial information, including income, expenses, savings, budget usage and financial health.

### Transactions

Allows users to record and manage income and expense transactions with categories and descriptions.

### Budget

Users can create monthly budgets and track their spending against the allocated budget.

### Savings & Debt

Provides tools for tracking savings goals and outstanding debts, including Emergency Fund and PTPTN allocation.

### Financial Analytics

Analyses financial activity to provide information such as spending patterns, savings rate, budget utilisation and overall financial health.

### AI Financial Assistant

Provides financial insights and assistance based on the user's financial information.

### Currency Converter

Supports conversion between:

`MYR` `USD` `SGD` `EUR` `GBP` `JPY` `CNY` `AUD`

### Report Export

Allows users to generate customised financial reports in **CSV** and **PDF** formats based on selected periods and financial data.

## Screenshots

> Screenshots of the application can be added here.

```text
docs/
└── screenshots/
    ├── dashboard.png
    ├── transactions.png
    ├── budget.png
    └── analytics.png
```

## Getting Started

### Prerequisites

Make sure the following are installed:

* Flutter SDK
* Dart SDK
* Android Studio or Visual Studio Code
* Git
* Firebase configuration

### Clone the Repository

```bash
git clone <your-repository-url>
cd <project-folder>
```

### Install Dependencies

```bash
flutter pub get
```

### Run the Application

```bash
flutter run
```

For web:

```bash
flutter run -d chrome
```

## Configuration

The application uses Firebase and external APIs.

Sensitive credentials, environment variables and private configuration files are not included in the public repository. The required Firebase and API configuration must be set up before running the application.
