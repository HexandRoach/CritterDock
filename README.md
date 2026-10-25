# CritterDock

Hatch an egg. Meet your Pip. Build a little life together.

CritterDock is a cozy virtual-pet prototype built with Godot 4. Raise original creatures called Pips, prepare meals, play together, keep their home clean, and speak to them through optional offline voice commands.

Inspired by the hands-on bonding and care of virtual-pet games, CritterDock focuses on original egg-hatched creatures, expressive behavior, and a warm little home.

> Early prototype: features, artwork, balancing, and save formats may change.

## Meet the Pips

There are six Pip types in the current prototype:

| Pip | Appearance | Current movement |
| --- | --- | --- |
| Moss | Sage-green fur, rounded ears, and a leaf sprout | Standard pace |
| Ember | Peach-orange fur, a pointed tuft, and a pointed tail | Faster |
| Moon | Lavender fur, drooping ears, and a crescent marking | Slower |
| Puddle | Powder-blue body, floppy ears, rounded tail, and smooth highlights | Standard pace |
| Pebble | Warm-gray fur, small ears, and rounded head ridges | Slower |
| Puff | Cream fur, large ears, fluffy cheeks, and a pom-pom tail | Standard pace |

Each Pip has its own egg, hatch status, needs, food, and cooking progress.

Only the selected Pip is visible and simulated. The other Pips pause safely while you care for someone else.

Full personality and training systems are planned; the current types share most care behaviors.

## Current Features

### Egg hatching

- Six colored and patterned eggs.
- Gentle idle wobbling.
- Stronger shaking and bouncing when clicked.
- Cracks that spread with each tap.
- A brief final struggle before hatching.
- Procedurally generated cracking sounds.
- An optional egg-sound toggle.

Tap an egg three times to hatch its Pip.

### Everyday care

Manage six needs:

- Hunger
- Energy
- Hygiene
- Fun
- Social
- Health

Pips can wander, follow your cursor, chase a ball, walk to their bed, sleep, and approach their food bowl to eat.

Clicking a Pip provides affection and restores social need.

### Cooking and meals

Prepare one of three fictional creature meals:

| Recipe | Preparation time | Fullness |
| --- | --- | --- |
| Garden porridge | 5 seconds | Medium |
| Pumpkin bean stew | 9 seconds | High |
| Berry oat cakes | 6 seconds | Lower |

Meals are eaten gradually. Food spoils after approximately ten minutes of active simulation for that Pip.

Use Clean to remove spoiled food or wash an empty dirty bowl.

Recipes and fullness values are game mechanics, not real animal nutrition guidance.

### Cozy and Standard modes

Cozy mode is enabled by default:

- Needs still decline.
- Health can deteriorate.
- Death is prevented.

Turn Cozy mode off for Standard mode:

- Sustained starvation or exhaustion reduces health.
- Critical-health warnings appear.
- Continued neglect can lead to death.

A new egg can replace a deceased Pip in that slot without resetting the other five.

The Cozy setting applies across the nursery.

### Saving

- Progress saves approximately every 15 seconds.
- Progress also saves on normal window close or Escape.
- Needs do not decline while the application is closed.
- Inactive Pip slots are paused.

Save files are stored in Godot's per-user application data, not in the project folder.

The current save is:

```text
user://critterdock_six_pips_v2.json
```

If no six-Pip save exists, the game can import the previous care prototype's save into the Moss slot:

```text
user://critterdock_care_v1.json
```

The old save file is left unchanged.

## Requirements

### Game

- Godot 4, standard edition.
- No .NET installation required.
- No external artwork required.
- The project uses the Compatibility renderer.

The prototype is being developed on Nobara Linux. Other operating systems and Godot versions need testing.

### Optional voice commands

- Python 3 with `venv` and `pip`.
- A working microphone.
- The `vosk` and `sounddevice` Python packages.
- A Vosk English speech-recognition model.
- PortAudio available on the system.

Voice setup is separate from launching the Godot project.

## Run the Project

1. Download or clone this repository.
2. Open Godot's Project Manager.
3. Import `project.godot`.
4. Open the project.
5. Press F5.

The main scene should contain:

```text
CritterDock
└── VoiceListener
```

`CritterDock.gd` belongs on the root node.

`VoiceListener.gd` belongs on its child node.

The game remains playable with buttons and mouse controls if the voice helper is not running.

## Controls

| Control | Action |
| --- | --- |
| Pip buttons across the top | Select a Pip |
| Click an egg three times | Hatch that Pip |
| Click a living Pip | Pet it |
| Meals | Open the recipe menu |
| Click a fresh food bowl | Send the Pip to eat |
| Sleep | Send the Pip to bed |
| Play | Chase the ball |
| Drag and release the ball | Move and throw the toy |
| Follow | Follow the cursor horizontally |
| Rest | Return to wandering |
| Clean | Restore hygiene and clean an empty or spoiled bowl |
| Cozy mode checkbox | Enable or disable death prevention |
| Egg sounds checkbox | Enable or disable cracking effects |
| Escape | Save and quit |

The care journal scrolls when its contents extend below the panel.

## Optional Offline Voice Setup

The voice helper captures microphone audio, recognizes supported phrases locally with Vosk, and sends commands to the game over a localhost UDP connection.

It does not upload audio or save recordings in the supplied implementation.

### 1. Install PortAudio

On Nobara or Fedora:

```bash
sudo dnf install portaudio
```

### 2. Create a Python environment

From the project folder:

```bash
cd voice
python3 -m venv .venv
source .venv/bin/activate
python -m pip install vosk sounddevice
```

### 3. Install the model

Download the small US English model, `vosk-model-small-en-us-0.15`, from:

https://alphacephei.com/vosk/models

Extract it and rename the extracted directory to `model`.

The structure should be:

```text
voice/
├── critter_voice.py
└── model/
    ├── am/
    ├── conf/
    ├── graph/
    └── ivector/
```

Avoid an extra nested model folder. This file should exist:

```text
voice/model/am/final.mdl
```

### 4. Start listening

Start the Godot game, then run this from the `voice` directory:

```bash
source .venv/bin/activate
python critter_voice.py
```

Say a supported command, then pause briefly.

### Voice commands

| Phrase | Action |
| --- | --- |
| “Come here” or “Follow me” | Follow the cursor |
| “Go to sleep” or “Bedtime” | Walk to bed and sleep |
| “Let's play” or “Play time” | Chase the ball |
| “Eat your food” or “Dinner time” | Eat if fresh food is available |
| “Good boy,” “Good girl,” or “Good pet” | Receive praise and restore social need |
| “Take a break” or “Stop following” | Return to wandering |

Commands affect the currently selected living, hatched Pip.

This is limited command recognition, not conversational AI or speaker identification. It does not yet require the creature's name.

### Choose a microphone

List devices:

```bash
python critter_voice.py --list-devices
```

Select one by its listed number:

```bash
python critter_voice.py --device 3
```

Replace `3` with your microphone's device number.

### Stop listening

Press Ctrl+C in the helper's terminal.

Closing Godot does not stop the Python helper. While the helper runs, it continuously captures microphone audio, and background speech may trigger commands.

The game listener uses UDP port `42425`, bound to `127.0.0.1`.

## Project Structure

```text
CritterDock/
├── project.godot
├── Main.tscn
├── CritterDock.gd
├── CritterDock.gd.uid
├── VoiceListener.gd
├── VoiceListener.gd.uid
├── README.md
└── voice/
    ├── critter_voice.py
    ├── model/       # Download separately; not committed
    └── .venv/       # Create locally; not committed
```

Godot cache files, Python environments, downloaded speech models, local builds, and common private configuration files are excluded through `.gitignore`.

## Current Limitations

- This is a normal-window 2D prototype, not a desktop overlay.
- Artwork is drawn procedurally; there are no finished 3D models.
- Pips move horizontally rather than freely through a 3D room.
- Only one Pip is visible and simulated at a time.
- Personality differences are limited.
- Hygiene, fun, and social are simplified systems.
- There is no detailed illness, veterinary treatment, inventory, or shopping system.
- Voice recognition can mishear speech or respond to background audio.
- Some voice messages still use the generic name “Pip.”
- Exporting the Godot game does not automatically package the Python voice helper or speech model.
- Compatibility across platforms still needs testing.
- Save formats may change during development.

## Testing Checklist

Please test:

- Selecting each Pip.
- Egg wobbling, cracking sounds, and hatching.
- Cooking all three meals.
- Walking to the bowl and finishing a meal.
- Going to bed and recovering energy.
- Petting, playing, following, and cleaning.
- Switching Pips without mixing their needs or food.
- Saving, closing, and reopening.
- Running the game without the voice helper.
- Voice commands with your microphone.

For spoilage and need-decay testing, remember that only the selected Pip's active time progresses.

### Reporting a bug

Include:

```text
Operating system:
Godot version:
Selected Pip:
Voice helper running: yes/no

What I did:
What I expected:
What actually happened:

Error text or screenshot:
```

Do not include passwords, private files, or personal audio recordings.

## Planned Direction

- A cozy 3D home.
- More expressive creature animations.
- Better petting and grooming.
- Toy fetching and training.
- Richer personalities and preferences.
- More recipes and home customization.
- Easier voice-helper startup and microphone controls.
- Packaged builds for friends to test.
- A future desktop companion mode.

These are goals, not features included in the current prototype.

## Credits

Created by Tyler Chirco.

Built with Godot. Optional speech recognition uses Vosk and python-sounddevice.

Third-party software and speech models retain their respective licenses.

No project license has been selected yet.
