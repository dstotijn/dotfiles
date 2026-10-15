import { execFileSync } from "node:child_process";
import { homedir } from "node:os";
import path from "node:path";
import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";

// Tells the agent it runs inside Herdr. The text comes from the shared
// herdr-agent-context script, which prints nothing outside Herdr.
function readHerdrContext(): string {
	try {
		return execFileSync(path.join(homedir(), ".local/bin/herdr-agent-context"), {
			encoding: "utf8",
			stdio: ["ignore", "pipe", "ignore"],
			timeout: 5000,
		}).trim();
	} catch {
		return "";
	}
}

export default function herdrContext(pi: ExtensionAPI): void {
	const context = readHerdrContext();
	if (!context) return;

	// OMP rebuilds the system prompt before each run and a returned systemPrompt
	// replaces it, so append to the prompt it hands over every time.
	pi.on("before_agent_start", (event) => ({
		systemPrompt: [...event.systemPrompt, context],
	}));
}
