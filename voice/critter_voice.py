import argparse
import json
import queue
import socket
import sys
import time
from pathlib import Path

import sounddevice as sd
from vosk import KaldiRecognizer, Model, SetLogLevel


HOST = "127.0.0.1"
PORT = 42425

COMMANDS = {
    "come here": "follow",
    "follow me": "follow",
    "go to sleep": "sleep",
    "bedtime": "sleep",
    "let's play": "play",
    "play time": "play",
    "eat your food": "eat",
    "dinner time": "eat",
    "good boy": "praise",
    "good girl": "praise",
    "good pet": "praise",
    "take a break": "rest",
    "stop following": "rest",
}


def device_value(value):
    try:
        return int(value)
    except ValueError:
        return value


def main():
    parser = argparse.ArgumentParser(
        description="CritterDock local microphone command helper."
    )
    parser.add_argument(
        "--list-devices",
        action="store_true",
        help="List audio devices without opening the microphone.",
    )
    parser.add_argument(
        "--device",
        type=device_value,
        default=None,
        help="Input device number or name.",
    )
    parser.add_argument(
        "--model",
        type=Path,
        default=Path(__file__).resolve().parent / "model",
        help="Path to the extracted Vosk model folder.",
    )
    args = parser.parse_args()

    if args.list_devices:
        print(sd.query_devices())
        return

    if not (args.model / "am" / "final.mdl").is_file():
        raise SystemExit(
            "Model not found.\n"
            "Extract the Vosk English model into voice/model.\n"
            "Expected file: " + str(args.model / "am" / "final.mdl")
        )

    audio_queue = queue.Queue(maxsize=100)
    connection = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

    def send_message(kind, **fields):
        packet = {
            "app": "critterdock_voice_v1",
            "kind": kind,
            **fields,
        }
        encoded = json.dumps(packet).encode("utf-8")
        connection.sendto(encoded, (HOST, PORT))

    def audio_callback(indata, frames, timing, status):
        if status:
            print("Audio warning:", status, file=sys.stderr)

        try:
            audio_queue.put_nowait(bytes(indata))
        except queue.Full:
            pass

    SetLogLevel(-1)

    print("Loading local speech model...")
    model = Model(str(args.model))

    device_info = sd.query_devices(args.device, "input")
    sample_rate = int(device_info["default_samplerate"])

    # A limited vocabulary is intended for this command test.
    # Unknown speech can still be misrecognized.
    grammar = json.dumps(list(COMMANDS.keys()) + ["[unk]"])
    recognizer = KaldiRecognizer(model, sample_rate, grammar)

    last_heartbeat = 0.0
    last_command_time = 0.0

    try:
        with sd.RawInputStream(
            samplerate=sample_rate,
            blocksize=4000,
            device=args.device,
            dtype="int16",
            channels=1,
            callback=audio_callback,
        ):
            print("Microphone active:", device_info["name"])
            print("Try: come here / go to sleep / let's play")
            print("Pause briefly after each command.")
            print("Press Ctrl+C here to STOP microphone capture.")

            while True:
                now = time.monotonic()

                if now - last_heartbeat >= 1.0:
                    send_message("heartbeat")
                    last_heartbeat = now

                try:
                    audio_data = audio_queue.get(timeout=0.25)
                except queue.Empty:
                    continue

                if not recognizer.AcceptWaveform(audio_data):
                    continue

                result = json.loads(recognizer.Result())
                text = result.get("text", "").strip().lower()

                if not text:
                    continue

                print("Heard:", text)
                send_message("heard", text=text)

                action = COMMANDS.get(text)

                if action is None:
                    continue

                now = time.monotonic()

                if now - last_command_time < 1.5:
                    continue

                send_message(
                    "command",
                    action=action,
                    text=text,
                )
                last_command_time = now
                print("Command:", action)

    except KeyboardInterrupt:
        print("\nMicrophone stopped.")

    finally:
        try:
            send_message("stopped")
        finally:
            connection.close()


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(
            f"{type(error).__name__}: {error}",
            file=sys.stderr,
        )
        sys.exit(1)