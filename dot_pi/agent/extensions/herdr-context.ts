import { execFileSync } from "node:child_process";
import { homedir } from "node:os";
import path from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

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

	pi.on("before_agent_start", (event) => {
		event.systemPromptOptions.sections.herdr = context;
	});
}
