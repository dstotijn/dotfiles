import { execFile } from "node:child_process";
import path from "node:path";
import type { ExtensionAPI, ExtensionCommandContext } from "@oh-my-pi/pi-coding-agent";

type ProcessOutput = {
	stdout: string;
	stderr: string;
};

type WorktreeItem = {
	branch?: string;
	worktree: {
		path: string;
		main: boolean;
		current?: boolean;
	};
};

type WorktreeInventory = {
	items: WorktreeItem[];
	mainCheckout: string;
};

type HerdrPane = {
	cwd?: string;
	foreground_cwd?: string;
	pane_id: string;
	tab_id: string;
	workspace_id: string;
};

type HerdrWorkspace = {
	workspace_id: string;
	worktree?: {
		checkout_path?: string;
	};
};

type PendingCleanup = {
	ctx: ExtensionCommandContext;
	mainCheckout: string;
	target: WorktreeItem;
	workspaceId?: string;
};

const POLL_INTERVAL_MS = 250;
const MAX_OUTPUT_BYTES = 1024 * 1024;

function run(command: string, args: string[], cwd: string): Promise<ProcessOutput> {
	const { promise, resolve, reject } = Promise.withResolvers<ProcessOutput>();
	execFile(
		command,
		args,
		{ cwd, encoding: "utf8", maxBuffer: MAX_OUTPUT_BYTES },
		(error, stdout, stderr) => {
			if (error) {
				Object.assign(error, { stdout, stderr });
				reject(error);
				return;
			}
			resolve({ stdout, stderr });
		},
	);
	return promise;
}

function failureMessage(error: unknown): string {
	const failure = error as Error & { stderr?: string; stdout?: string };
	const message = failure.stderr?.trim() || failure.stdout?.trim() || failure.message || String(error);
	return message.replaceAll(/\s+/g, " ").slice(0, 500);
}

function parseJson(output: string, source: string) {
	try {
		return JSON.parse(output);
	} catch {
		throw new Error(`${source} returned invalid JSON`);
	}
}

async function worktreeInventory(cwd: string): Promise<WorktreeInventory> {
	const { stdout } = await run("wt", ["-C", cwd, "list", "--format", "json"], cwd);
	const parsed = parseJson(stdout, "wt list");
	const items = Array.isArray(parsed.items)
		? parsed.items.filter(
				(item: WorktreeItem) =>
					typeof item?.worktree?.path === "string" && typeof item.worktree.main === "boolean",
			)
		: [];
	const mainCheckout = items.find((item: WorktreeItem) => item.worktree.main)?.worktree.path;
	if (!mainCheckout) {
		throw new Error("Worktrunk did not report the repository's main checkout");
	}
	return { items, mainCheckout: path.resolve(mainCheckout) };
}

function isInside(parent: string, child: string): boolean {
	const relative = path.relative(path.resolve(parent), path.resolve(child));
	return relative === "" || (!relative.startsWith("..") && !path.isAbsolute(relative));
}

function samePath(left: string | undefined, right: string): boolean {
	return typeof left === "string" && path.resolve(left) === path.resolve(right);
}

function resolveWorktree(items: WorktreeItem[], target: string | undefined, cwd: string): WorktreeItem | undefined {
	if (!target) {
		return (
			items
				.filter((item) => isInside(item.worktree.path, cwd))
				.sort((left, right) => right.worktree.path.length - left.worktree.path.length)[0] ??
			items.find((item) => item.worktree.current)
		);
	}
	const absoluteTarget = path.resolve(cwd, target);
	return items.find(
		(item) => item.branch === target || samePath(item.worktree.path, absoluteTarget),
	);
}

function tokenize(input: string): string[] {
	const tokens: string[] = [];
	let token = "";
	let quote: "'" | '"' | undefined;
	let escaped = false;

	for (const character of input.trim()) {
		if (escaped) {
			token += character;
			escaped = false;
			continue;
		}
		if (character === "\\" && quote !== "'") {
			escaped = true;
			continue;
		}
		if (quote) {
			if (character === quote) quote = undefined;
			else token += character;
			continue;
		}
		if (character === "'" || character === '"') {
			quote = character;
			continue;
		}
		if (/\s/.test(character)) {
			if (token) {
				tokens.push(token);
				token = "";
			}
			continue;
		}
		token += character;
	}

	if (escaped) token += "\\";
	if (quote) throw new Error("Unclosed quote in /wtx arguments");
	if (token) tokens.push(token);
	return tokens;
}

function herdrEnabled(): boolean {
	return process.env.HERDR_ENV === "1" && !!process.env.HERDR_PANE_ID;
}

async function herdr(args: string[], cwd: string) {
	const { stdout } = await run("herdr", args, cwd);
	const parsed = parseJson(stdout, `herdr ${args.slice(0, 2).join(" ")}`);
	if (!parsed?.result) throw new Error("Herdr returned no result");
	return parsed.result;
}

async function freshAgentName(branch: string, workspaceId: string, cwd: string): Promise<string> {
	const result = await herdr(["agent", "list"], cwd);
	const taken = new Set<string>(
		Array.isArray(result.agents)
			? result.agents.flatMap((agent: { name?: unknown }) =>
					typeof agent.name === "string" ? [agent.name] : [],
				)
			: [],
	);
	const issueName = branch.match(/(?:^|\/)([a-z]+-\d+)\b/i)?.[1]?.toLowerCase();
	const sanitizedBranch = branch
		.toLowerCase()
		.replaceAll(/[^a-z0-9_-]+/g, "-")
		.replace(/^[^a-z]+/, "")
		.replace(/[-_]+$/, "");
	const candidate = issueName || sanitizedBranch || `wtx-${workspaceId.toLowerCase()}`;
	const base = candidate.slice(0, 32).replace(/[-_]+$/, "");
	if (!taken.has(base)) return base;

	const suffix = `-${workspaceId.toLowerCase()}`;
	const prefix = base.slice(0, 32 - suffix.length).replace(/[-_]+$/, "");
	return `${prefix}${suffix}`;
}

async function herdrCurrentPane(cwd: string): Promise<HerdrPane> {
	const result = await herdr(["pane", "current", "--current"], cwd);
	if (!result.pane?.pane_id) throw new Error("Herdr did not report the current pane");
	return result.pane;
}

async function herdrWorkspaces(cwd: string): Promise<HerdrWorkspace[]> {
	const result = await herdr(["workspace", "list"], cwd);
	return Array.isArray(result.workspaces) ? result.workspaces : [];
}

async function herdrPanes(workspaceId: string, cwd: string): Promise<HerdrPane[]> {
	const result = await herdr(["pane", "list", "--workspace", workspaceId], cwd);
	return Array.isArray(result.panes) ? result.panes : [];
}

async function findWorkspaceForCheckout(checkout: string, cwd: string): Promise<string | undefined> {
	const current = await herdrCurrentPane(cwd);
	const workspaces = await herdrWorkspaces(cwd);
	const matches = workspaces
		.filter((workspace) => samePath(workspace.worktree?.checkout_path, checkout))
		.map((workspace) => workspace.workspace_id);

	if (matches.length > 0) {
		return matches.includes(current.workspace_id) ? current.workspace_id : matches[0];
	}

	for (const workspace of workspaces.filter((candidate) => !candidate.worktree?.checkout_path)) {
		const panes = await herdrPanes(workspace.workspace_id, cwd);
		if (panes.some((pane) => samePath(pane.cwd, checkout) || samePath(pane.foreground_cwd, checkout))) {
			matches.push(workspace.workspace_id);
		}
	}

	return matches.includes(current.workspace_id) ? current.workspace_id : matches[0];
}

async function ensureMainWorkspace(mainCheckout: string, cwd: string): Promise<string> {
	const existing = await findWorkspaceForCheckout(mainCheckout, cwd);
	if (existing) return existing;

	const result = await herdr(
		["workspace", "create", "--cwd", mainCheckout, "--label", path.basename(mainCheckout), "--no-focus"],
		cwd,
	);
	const workspaceId = result.workspace?.workspace_id;
	if (!workspaceId) throw new Error("Herdr did not report the new main workspace");
	return workspaceId;
}

async function openHerdrWorktree(
	mainWorkspaceId: string,
	worktreePath: string,
	label: string,
	cwd: string,
): Promise<{ workspaceId: string; rootPaneId: string; alreadyOpen: boolean }> {
	const result = await herdr(
		[
			"worktree",
			"open",
			"--workspace",
			mainWorkspaceId,
			"--path",
			worktreePath,
			"--label",
			label,
			"--no-focus",
		],
		cwd,
	);
	const workspaceId = result.workspace?.workspace_id;
	const rootPaneId = result.root_pane?.pane_id;
	if (!workspaceId || !rootPaneId) {
		throw new Error("Herdr did not report the opened worktree workspace");
	}
	return { workspaceId, rootPaneId, alreadyOpen: result.already_open === true };
}

async function removeWorktree(target: WorktreeItem, mainCheckout: string) {
	await run(
		"wt",
		["-C", mainCheckout, "remove", "--foreground", "--format", "json", target.worktree.path],
		mainCheckout,
	);
}

export default function wtx(pi: ExtensionAPI): void {
	let pendingCleanup: PendingCleanup | undefined;
	let cleanupTimer: NodeJS.Timeout | undefined;

	async function finishCleanup(pending: PendingCleanup) {
		try {
			if (pending.workspaceId) {
				const workspaces = await herdrWorkspaces(pending.mainCheckout);
				if (workspaces.some((workspace) => workspace.workspace_id === pending.workspaceId)) {
					await herdr(["workspace", "close", pending.workspaceId], pending.mainCheckout);
				}
			}
			await removeWorktree(pending.target, pending.mainCheckout);
			pending.ctx.ui.notify(
				`Removed ${pending.target.branch ?? pending.target.worktree.path} with Worktrunk`,
				"info",
			);
		} catch (error) {
			pending.ctx.ui.notify(`Cleanup failed: ${failureMessage(error)}`, "error");
		} finally {
			pendingCleanup = undefined;
		}
	}

	function waitForMoveBeforeCleanup(pending: PendingCleanup) {
		pendingCleanup = pending;
		cleanupTimer = setInterval(() => {
			if (isInside(pending.target.worktree.path, process.cwd())) return;
			if (!isInside(pending.mainCheckout, process.cwd())) return;
			clearInterval(cleanupTimer);
			cleanupTimer = undefined;
			void finishCleanup(pending);
		}, POLL_INTERVAL_MS);
		cleanupTimer.unref?.();
	}

	async function open(args: string[], ctx: ExtensionCommandContext) {
		const cwd = process.cwd();
		const create = args[0] === "create";
		let target = args[create || args[0] === "open" ? 1 : 0];
		const base = create ? args[2] : undefined;

		if (!target && ctx.hasUI) {
			target = await ctx.ui.input(create ? "Create Worktrunk branch" : "Open Worktrunk checkout", "Branch or path");
		}
		if (!target) {
			ctx.ui.notify("Usage: /wtx [open] <branch-or-path> | /wtx create <branch> [base]", "error");
			return;
		}

		const switchArgs = ["-C", cwd, "switch", "--no-cd", "--format", "json"];
		if (create) switchArgs.push("--create");
		if (base) switchArgs.push("--base", base);
		switchArgs.push(target);

		const { stdout } = await run("wt", switchArgs, cwd);
		const switched = parseJson(stdout, "wt switch");
		if (typeof switched.path !== "string") throw new Error("Worktrunk did not report a checkout path");
		const worktreePath = path.resolve(switched.path);
		const inventory = await worktreeInventory(worktreePath);
		const selected = inventory.items.find((item) => samePath(item.worktree.path, worktreePath));
		const branchName =
			selected?.branch ??
			(typeof switched.branch === "string" ? switched.branch : undefined);
		const workspaceLabel = branchName?.split("/").at(-1) || path.basename(worktreePath);

		if (samePath(worktreePath, inventory.mainCheckout) || !herdrEnabled()) {
			ctx.ui.setEditorText(`/move ${worktreePath}`);
			ctx.ui.notify(
				herdrEnabled()
					? "Checkout selected; press Enter to move this OMP session"
					: "Checkout selected outside Herdr; press Enter to move this OMP session",
				"info",
			);
			return;
		}

		const mainWorkspaceId = await ensureMainWorkspace(inventory.mainCheckout, cwd);
		const opened = await openHerdrWorktree(mainWorkspaceId, worktreePath, workspaceLabel, cwd);
		await herdr(["workspace", "rename", opened.workspaceId, workspaceLabel], cwd);

		if (opened.alreadyOpen) {
			await herdr(["workspace", "focus", opened.workspaceId], cwd);
			ctx.ui.notify(`Focused existing ${workspaceLabel} workspace`, "info");
			return;
		}
		const agentName = await freshAgentName(workspaceLabel, opened.workspaceId, cwd);

		await herdr(
			[
				"pane",
				"split",
				opened.rootPaneId,
				"--direction",
				"right",
				"--cwd",
				worktreePath,
				"--no-focus",
			],
			cwd,
		);
		await herdr(
			[
				"agent",
				"start",
				agentName,
				"--kind",
				"omp",
				"--pane",
				opened.rootPaneId,
			],
			cwd,
		);
		await herdr(["workspace", "focus", opened.workspaceId], cwd);
		ctx.ui.notify(`Started a fresh OMP session in ${workspaceLabel}`, "info");
	}

	async function remove(args: string[], ctx: ExtensionCommandContext) {
		const cwd = process.cwd();
		const inventory = await worktreeInventory(cwd);
		const target = resolveWorktree(inventory.items, args[1], cwd);
		if (!target) throw new Error("No matching Worktrunk checkout");
		if (target.worktree.main) throw new Error("The repository's main checkout cannot be removed");

		const currentUsesTarget = target.worktree.current === true || isInside(target.worktree.path, cwd);
		if (!herdrEnabled()) {
			if (!currentUsesTarget) {
				await removeWorktree(target, inventory.mainCheckout);
				ctx.ui.notify(`Removed ${target.branch ?? target.worktree.path} with Worktrunk`, "info");
				return;
			}
			waitForMoveBeforeCleanup({ ctx, mainCheckout: inventory.mainCheckout, target });
			ctx.ui.setEditorText(`/move ${inventory.mainCheckout}`);
			ctx.ui.notify("Press Enter to leave the worktree; cleanup will continue after the move", "info");
			return;
		}

		const current = await herdrCurrentPane(cwd);
		const workspaceId = currentUsesTarget
			? current.workspace_id
			: await findWorkspaceForCheckout(target.worktree.path, cwd);

		if (!currentUsesTarget) {
			if (workspaceId) await herdr(["workspace", "close", workspaceId], cwd);
			await removeWorktree(target, inventory.mainCheckout);
			ctx.ui.notify(`Removed ${target.branch ?? target.worktree.path} with Worktrunk`, "info");
			return;
		}

		const mainWorkspaceId = await ensureMainWorkspace(inventory.mainCheckout, cwd);
		const [mainPane] = await herdrPanes(mainWorkspaceId, cwd);
		if (!mainPane) throw new Error("Herdr main workspace has no usable pane");
		await herdr(
			[
				"pane",
				"move",
				current.pane_id,
				"--tab",
				mainPane.tab_id,
				"--split",
				"right",
				"--target-pane",
				mainPane.pane_id,
				"--focus",
			],
			cwd,
		);
		waitForMoveBeforeCleanup({
			ctx,
			mainCheckout: inventory.mainCheckout,
			target,
			workspaceId: workspaceId === mainWorkspaceId ? undefined : workspaceId,
		});
		ctx.ui.setEditorText(`/move ${inventory.mainCheckout}`);
		ctx.ui.notify("Press Enter to leave the worktree; Herdr and Worktrunk cleanup will then continue", "info");
	}

	pi.registerCommand("wtx", {
		description: "Create, open, or remove a Worktrunk checkout with Herdr",
		handler: async (rawArgs, ctx) => {
			if (pendingCleanup) {
				ctx.ui.notify("A /wtx cleanup is waiting for its /move command", "error");
				return;
			}
			try {
				const args = tokenize(rawArgs);
				if (args[0] === "help") {
					ctx.ui.notify(
						"/wtx [open] <branch-or-path> | /wtx create <branch> [base] | /wtx remove [branch-or-path]",
						"info",
					);
					return;
				}
				if (args[0] === "remove") await remove(args, ctx);
				else await open(args, ctx);
			} catch (error) {
				ctx.ui.notify(`/wtx failed: ${failureMessage(error)}`, "error");
			}
		},
	});

	pi.on("session_shutdown", () => {
		clearInterval(cleanupTimer);
		cleanupTimer = undefined;
		pendingCleanup = undefined;
	});
}
