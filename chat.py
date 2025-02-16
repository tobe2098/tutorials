#!/usr/bin/env python3
import subprocess
import json
import os
import signal
import sys
import argparse
from datetime import datetime

class LLMChat:
    def __init__(self, model_path=None, n_gpu_layers=None, ctx_size=None, prompt_file=None):
        self.config = self.load_system_config()
        self.model_path = model_path or self.config.get('model_path')
        self.n_gpu_layers = n_gpu_layers or self.config.get('default_gpu_layers', 35)
        self.ctx_size = ctx_size or self.config.get('default_ctx_size', 4096)
        self.history_dir = os.path.expanduser("~/.llm_chat_history")
        self.ensure_history_dir()
        self.context = []
        if prompt_file:
            self.load_initial_prompt(prompt_file)

    def load_system_config(self):
        config_path = "/opt/llm-chat/config/system.json"
        try:
            with open(config_path, 'r') as f:
                return json.load(f)
        except FileNotFoundError:
            return {}

    def load_initial_prompt(self, prompt_file):
        try:
            prompt_path = os.path.join("/opt/llm-chat/prompts", prompt_file)
            if not prompt_path.endswith('.txt'):
                prompt_path += '.txt'
            with open(prompt_path, 'r') as f:
                prompt = f.read().strip()
            if prompt:
                self.context.append({"role": "system", "content": prompt})
                print(f"\nLoaded initial prompt from: {prompt_path}")
        except FileNotFoundError:
            print(f"\nPrompt file not found: {prompt_path}")

    def ensure_history_dir(self):
        if not os.path.exists(self.history_dir):
            os.makedirs(self.history_dir)

    def start_process(self):
        return subprocess.Popen(
            [
                "./main",
                "-m", self.model_path,
                "--n-gpu-layers", str(self.n_gpu_layers),
                "--ctx-size", str(self.ctx_size),
                "--color",
                "--interactive"
            ],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )

    def format_context(self, user_input):
        context_str = ""
        for msg in self.context:
            context_str += f"{msg['role'].title()}: {msg['content']}\n"
        return context_str + f"User: {user_input}\nAssistant: "

    def save_history(self, name=None):
        if name is None:
            name = datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = os.path.join(self.history_dir, f"chat_{name}.json")
        with open(filename, "w") as f:
            json.dump(self.context, f, indent=2)
        print(f"\nHistory saved to: {filename}")

    def load_history(self, name):
        try:
            filename = os.path.join(self.history_dir, f"chat_{name}.json")
            with open(filename, "r") as f:
                self.context = json.load(f)
            print(f"\nLoaded history from: {filename}")
        except FileNotFoundError:
            print(f"\nNo history file found with name: {name}")

    def delete_history(self, name):
        try:
            filename = os.path.join(self.history_dir, f"chat_{name}.json")
            os.remove(filename)
            print(f"\nDeleted history: {name}")
        except FileNotFoundError:
            print(f"\nNo history file found with name: {name}")

    def list_histories(self):
        files = os.listdir(self.history_dir)
        if not files:
            print("\nNo chat histories found.")
            return
        print("\nAvailable chat histories:")
        for f in sorted(files):
            if f.endswith('.json'):
                print(f"- {f[5:-5]}")  # Remove 'chat_' prefix and '.json' suffix

    def list_prompts(self):
        prompts_dir = "/opt/llm-chat/prompts"
        files = [f for f in os.listdir(prompts_dir) if f.endswith('.txt')]
        if not files:
            print("\nNo prompt files found.")
            return
        print("\nAvailable prompt files:")
        for f in sorted(files):
            print(f"- {f[:-4]}")  # Remove '.txt' suffix

    def clear_context(self):
        self.context = []
        print("\nChat context cleared.")

    def run(self):
        print(f"\n=== LLM Chat Session ===")
        print(f"GPU Layers: {self.n_gpu_layers}")
        print(f"Context Size: {self.ctx_size}")
        print("Commands:")
        print("  /exit - End chat session")
        print("  /clear - Clear current context")
        print("  /save [name] - Save chat history")
        print("  /load <name> - Load chat history")
        print("  /delete <name> - Delete chat history")
        print("  /list - List saved histories")
        print("  /prompts - List available prompt files")
        print("  /context - Show current context")
        print("=====================\n")

        process = self.start_process()

        while True:
            try:
                user_input = input("\033[94mYou:\033[0m ").strip()

                if not user_input:
                    continue

                if user_input.startswith('/'):
                    cmd = user_input[1:].split()
                    if cmd[0] == 'exit':
                        break
                    elif cmd[0] == 'clear':
                        self.clear_context()
                        continue
                    elif cmd[0] == 'save':
                        name = cmd[1] if len(cmd) > 1 else None
                        self.save_history(name)
                        continue
                    elif cmd[0] == 'load':
                        if len(cmd) > 1:
                            self.load_history(cmd[1])
                        else:
                            print("Please specify a history name to load")
                        continue
                    elif cmd[0] == 'delete':
                        if len(cmd) > 1:
                            self.delete_history(cmd[1])
                        else:
                            print("Please specify a history name to delete")
                        continue
                    elif cmd[0] == 'list':
                        self.list_histories()
                        continue
                    elif cmd[0] == 'prompts':
                        self.list_prompts()
                        continue
                    elif cmd[0] == 'context':
                        print("\nCurrent context:")
                        for msg in self.context:
                            print(f"{msg['role'].title()}: {msg['content']}")
                        continue

                self.context.append({"role": "user", "content": user_input})
                prompt = self.format_context(user_input)

                process.stdin.write(prompt + "\n")
                process.stdin.flush()

                print("\033[92mAssistant:\033[0m ", end="", flush=True)
                response = ""
                while True:
                    char = process.stdout.read(1)
                    if char == '\n' and response.endswith("User: "):
                        response = response[:-6]  # Remove "User: "
                        break
                    response += char
                    print(char, end="", flush=True)

                self.context.append({"role": "assistant", "content": response.strip()})
                print()  # Add newline after response

                # Manage context window
                if len(self.context) > 20:  # Adjust this number based on your needs
                    self.context = self.context[-20:]

            except KeyboardInterrupt:
                print("\nUse /exit to end the session")
                continue

def main():
    parser = argparse.ArgumentParser(description="LLM Chat Interface")
    parser.add_argument("--model", help="Path to model file")
    parser.add_argument("--gpu-layers", type=int, help="Number of GPU layers")
    parser.add_argument("--ctx-size", type=int, help="Context size")
    parser.add_argument("--prompt", help="Initial prompt file name")
    args = parser.parse_args()

    signal.signal(signal.SIGINT, lambda sig, frame: None)

    chat = LLMChat(
        model_path=args.model,
        n_gpu_layers=args.gpu_layers,
        ctx_size=args.ctx_size,
        prompt_file=args.prompt
    )

    chat.run()

if __name__ == "__main__":
    main()
