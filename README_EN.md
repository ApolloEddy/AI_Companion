# AI Companion - Cognitive Architecture Framework

![License](https://img.shields.io/badge/license-MIT-blue.svg) ![Flutter](https://img.shields.io/badge/Flutter-3.0%2B-02569B) ![Dart](https://img.shields.io/badge/Dart-3.0%2B-0175C2)

**[English](README_EN.md) | [中文](README.md)**

> **v2.8.0 Update**: UI/UX polished! Added dropdown gender selection, global breathing animation feedback dialogs, and optimized localized prompts.

---

# English Documentation

**AI Companion** is a "digital life" framework driven by a **Closed-Loop Cognitive Architecture**, distinct from typical stateless LLM wrappers. It integrates psychological modeling to give the AI internal state, emotional persistence, and dynamic personality evolution.

## 🏗️ 3-Layer Cognitive Architecture (L1-L3)

The system operates on a unidirectional cognitive pipeline inspired by human cognition.

```mermaid
graph TD
    User --> L1[L1: Perception Core]
    L1 -->|Perception Result| L2[L2: Decision Core]
    State[Emotional State (Memory)] --> L2
    Config[Personality Config] --> L2
    L2 -->|Inner Monologue| L3[L3: Expression Core]
    L3 -->|System Prompt| LLM
    LLM --> Output
```

### L1: Perception Core

Acts as the sensory cortex. It analyzes input without generating a response.

- **Offensiveness (0-10)**: Detects hostility (playful teasing vs. malicious attacks).
- **Underlying Needs**: Identifies implicit needs (e.g., *need for comfort*, *apology*, *praise*).
- **Time Sensitivity**: Determines if the physical time context is relevant (e.g., "Good morning").

### L2: Decision Core (The Brain)

The fusion center where "Thinking" happens. It combines:

- **Perception**: What the user said.
- **Emotion (V-A-R)**: How the AI feels right now.
- **Personality (Big Five)**: The AI's innate traits.

It generates an **Inner Monologue** (private thought) and a **Response Strategy** (Pacing, Topic Depth).

### L3: Expression Core (The Mouth)

Translates abstract decisions into natural language instructions for the LLM.

- **Tone Mapping**: "High Arousal + High Valence" -> "Excited/Playful".
- **Pacing Control**: Appends instructions for `single_shot` or `burst` mode.
- **Constraint Enforcement**: Ensures no forbidden patterns or lengths are violated.

## 🧠 Psychological Models & Formulas

### 1. H-E-I Feedback Loop (Emotion Dynamics)

A unified model coupling **Hostility**, **Emotion**, and **Intimacy**.

#### V-A-R Emotion Model

Based on the Russell Circumplex Model, extended with a Z-axis: **Resentment**.
We use a non-linear update function with soft boundaries:

```math
E_{t} = E_{t-1} + \Delta E_{stimulus} \times (1 - |E_{t-1}|)^\alpha
```

- **Valence (V)**: Pleasure vs. Displeasure (-1 to 1).
- **Arousal (A)**: Energy vs. Lethargy (0 to 1).
- **Resentment (R)**: Accumulated grudges (0 to 1). *High R blocks positive emotion.*

#### Intimacy Growth Function

Intimacy is not a linear counter. It follows a logarithmic growth curve governed by:

```math
\Delta I = Q \times E \times T \times B(I)
```

- **Q (Quality)**: $f(Confidence, Valence) - (Offense \times 0.1)$
- **E (Emotion Multiplier)**: $1 + (Valence \times 0.3)$ *(Happy AI bonds 1.3x faster)*
- **T (Time Factor)**: Penalizes spamming; rewards spaced interactions.
- **B (Marginal Utility)**: $(1 - I)^{0.5}$ *(Harder to level up at high tiers)*

### 2. Personality Engine (Big Five)

> **v2.8.0 Feature**: Supports intuitive "Personality Genesis Radar" for drag-and-drop persona sculpting and real-time drift monitoring.

Based on the OCEAN model, evolving through user feedback.

Personality evolves based on user feedback (reinforcement learning).

```math
\Delta Trait_i = D \times M \times A_i \times I \times P(t)
```

- **O**penness: Affects topic depth preference.
- **C**onscientiousness: Affects instruction adherence.
- **E**xtraversion: Affects burst mode probability.
- **A**greeableness: Affects tolerance threshold for hostility.
- **N**euroticism: Multiplier for negative emotional reactions.

## 🚀 Deployment

### Prerequisites

- Flutter SDK 3.10+
- Dart 3.0+
- Valid OpenAI (or compatible) API Key

### Quick Start

```bash
git clone https://github.com/ApolloEddy/AI_Companion.git
flutter pub get
flutter run -d windows # or android
```

### License

MIT License
