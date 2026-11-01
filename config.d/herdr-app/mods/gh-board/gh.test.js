// node --test config.d/herdr-app/mods/gh-board
import { test } from "node:test";
import assert from "node:assert/strict";
import * as gh from "./gh.js";

const pr = (over = {}) => ({
  id: "PR_1", number: 7, title: "t", url: "https://github.com/a/b/pull/7", isDraft: false, isCrossRepository: false,
  author: { login: "me" }, headRefName: "fix", baseRefName: "main", headRefOid: "abc",
  mergeable: "MERGEABLE", mergeStateStatus: "CLEAN", reviewDecision: null, autoMergeRequest: null,
  commits: { nodes: [{ commit: { statusCheckRollup: { state: "SUCCESS" } } }] }, ...over,
});

const repo = (prs = [pr()]) => ({
  nameWithOwner: "a/b", url: "https://github.com/a/b", viewerPermission: "ADMIN",
  squashMergeAllowed: true, mergeCommitAllowed: false, rebaseMergeAllowed: false, autoMergeAllowed: true,
  issues: { totalCount: 3 }, latestRelease: null,
  defaultBranchRef: { name: "main", target: { oid: "def", statusCheckRollup: { state: "SUCCESS" }, checkSuites: { nodes: [
    { status: "COMPLETED", conclusion: "SUCCESS", workflowRun: { databaseId: 1, runNumber: 1, event: "push", url: "u", workflow: { name: "CI" } } },
    { status: "QUEUED", conclusion: null, workflowRun: null },
  ] } } },
  pullRequests: { totalCount: prs.length, nodes: prs },
});

test("boardQuery aliases each repo and escapes names", () => {
  const { query, aliases } = gh.boardQuery(["a/b", "c/d.e"]);
  assert.deepEqual(aliases, { r0: "a/b", r1: "c/d.e" });
  assert.match(query, /r1: repository\(owner: "c", name: "d\.e"\)/);
  assert.match(query, /rateLimit/);
});

test("boardQuery skips malformed names instead of breaking the query", () => {
  const { query } = gh.boardQuery(['x") { evil }']);
  assert.doesNotMatch(query, /evil/);
});

test("parseBoard keeps good repos when another alias errors", () => {
  const json = {
    data: { viewer: { login: "me" }, rateLimit: { cost: 1, remaining: 10 }, r0: repo(), r1: null },
    errors: [{ type: "NOT_FOUND", path: ["r1"], message: "Could not resolve to a Repository" }],
  };
  const out = gh.parseBoard(json, { r0: "a/b", r1: "gone/repo" });
  assert.equal(out.error, null);
  assert.equal(out.repos["a/b"].prs.length, 1);
  assert.equal(out.repos["gone/repo"].error, "Could not resolve to a Repository");
  assert.equal(out.viewer, "me");
});

test("parseBoard reports a request-level error on every repo without data", () => {
  const out = gh.parseBoard({ errors: [{ message: "Bad credentials" }] }, { r0: "a/b" });
  assert.equal(out.repos["a/b"].error, "Bad credentials");
});

test("repoModel drops check suites without a workflow run and lists newest first", () => {
  const m = gh.repoModel(repo());
  assert.equal(m.runs.length, 1);
  assert.equal(m.runs[0].name, "CI");
});

test("mergeState", () => {
  assert.equal(gh.mergeState(pr({ isDraft: true })), "draft");
  assert.equal(gh.mergeState(pr({ mergeable: "CONFLICTING", mergeStateStatus: "DIRTY" })), "conflict");
  assert.equal(gh.mergeState(pr({ mergeable: "UNKNOWN", mergeStateStatus: "UNKNOWN" })), "unknown");
  assert.equal(gh.mergeState(pr({ mergeStateStatus: "BEHIND" })), "behind");
  assert.equal(gh.mergeState(pr({ mergeStateStatus: "BLOCKED" })), "blocked");
  assert.equal(gh.mergeState(pr({ mergeStateStatus: "HAS_HOOKS" })), "clean");
});

test("isHot while anything will change without us", () => {
  const now = Date.parse("2026-11-01T12:00:00Z"), updatedAt = "2026-11-01T11:59:00Z";
  assert.equal(gh.isHot(gh.repoModel(repo()), now), false);
  assert.equal(gh.isHot(gh.repoModel(repo([pr({ updatedAt, commits: { nodes: [{ commit: { statusCheckRollup: { state: "PENDING" } } }] } })])), now), true);
  assert.equal(gh.isHot(gh.repoModel(repo([pr({ updatedAt, mergeable: "UNKNOWN" })])), now), true);
  assert.equal(gh.isHot({ error: "x" }), false);
});

test("rerunPlan separates checks no Actions run can rerun", () => {
  const checks = gh.checksModel([
    { __typename: "CheckRun", name: "a", status: "COMPLETED", conclusion: "FAILURE", checkSuite: { workflowRun: { databaseId: 5 } } },
    { __typename: "CheckRun", name: "b", status: "COMPLETED", conclusion: "FAILURE", checkSuite: { workflowRun: { databaseId: 5 } } },
    { __typename: "CheckRun", name: "c", status: "COMPLETED", conclusion: "FAILURE", checkSuite: { workflowRun: null } },
    { __typename: "StatusContext", context: "ci/legacy", state: "ERROR" },
    { __typename: "CheckRun", name: "d", status: "COMPLETED", conclusion: "SUCCESS", checkSuite: { workflowRun: { databaseId: 6 } } },
  ]);
  assert.equal(checks[0].state, "fail");
  assert.deepEqual(gh.rerunPlan(checks), { runs: [5], stuck: ["c", "ci/legacy"] });
});

test("agentPrompt names the base, the head oid and the failing runs", () => {
  const p = gh.prModel(pr({ mergeable: "CONFLICTING", mergeStateStatus: "DIRTY" }));
  const checks = gh.checksModel([{ __typename: "CheckRun", name: "lint", status: "COMPLETED", conclusion: "FAILURE", checkSuite: { workflowRun: { databaseId: 9 } } }]);
  const text = gh.agentPrompt("a/b", p, checks);
  assert.match(text, /abc/);
  assert.match(text, /merge origin\/main in/);
  assert.match(text, /gh run view 9 -R a\/b --log-failed/);
  assert.match(text, /lint/);
});

test("dispatchInfo", () => {
  assert.deepEqual(gh.dispatchInfo("on:\n  push:\n"), { dispatch: false, inputs: false });
  assert.deepEqual(gh.dispatchInfo("on:\n  workflow_dispatch:\n  push:\n"), { dispatch: true, inputs: false });
  assert.deepEqual(gh.dispatchInfo("on: workflow_dispatch\n"), { dispatch: true, inputs: false });
  assert.deepEqual(gh.dispatchInfo("on: [push, workflow_dispatch]\n"), { dispatch: true, inputs: false });
  assert.deepEqual(gh.dispatchInfo("on:\n  workflow_dispatch:\n    inputs:\n      v:\n        required: true\n        default: x\n"), { dispatch: true, inputs: true });
  // Inputs elsewhere (workflow_call, a step's with:) are not the dispatch's.
  assert.deepEqual(gh.dispatchInfo("on:\n  workflow_dispatch:\n  workflow_call:\n    inputs:\n      v:\n        required: true\n"), { dispatch: true, inputs: false });
});

test("workflowsModel strips trailing comments from names", () => {
  const json = { data: { repository: { object: { entries: [{ name: "ci.yml", path: ".github/workflows/ci.yml", object: { text: "name: CI # main\non: push\n" } }, { name: "README.md", object: { text: "" } }] } } } };
  assert.deepEqual(gh.workflowsModel(json).map((w) => w.name), ["CI"]);
});

test("restRunModel marks release runs by event, tag or workflow path", () => {
  const run = (o) => ({ id: 1, status: "completed", conclusion: "success", event: "push", head_branch: "1.x", path: ".github/workflows/ci.yml", ...o });
  assert.equal(gh.restRunModel(run()).release, false);
  assert.equal(gh.restRunModel(run({ head_branch: "v1.2.0" }), new Set(["v1.2.0"])).release, true);
  assert.equal(gh.restRunModel(run({ event: "release" })).release, true);
  assert.equal(gh.restRunModel(run({ path: ".github/workflows/release.yml" })).release, true);
  assert.equal(gh.restRunModel(run({ event: "pull_request", path: ".github/workflows/release.yml" })).release, false);
});

test("isHot ignores pending states that have gone stale", () => {
  const now = Date.parse("2026-11-01T12:00:00Z");
  const pending = { nodes: [{ commit: { statusCheckRollup: { state: "EXPECTED" } } }] };
  assert.equal(gh.isHot(gh.repoModel(repo([pr({ commits: pending, updatedAt: "2026-11-01T11:50:00Z" })])), now), true);
  assert.equal(gh.isHot(gh.repoModel(repo([pr({ commits: pending, updatedAt: "2026-10-30T11:50:00Z" })])), now), false);
  // Auto-merge waiting on a review is not about to change.
  assert.equal(gh.isHot(gh.repoModel(repo([pr({ autoMergeRequest: { mergeMethod: "SQUASH" }, mergeStateStatus: "BLOCKED", updatedAt: "2026-11-01T11:59:00Z" })])), now), false);
  assert.equal(gh.isHot(gh.repoModel(repo([pr({ autoMergeRequest: { mergeMethod: "SQUASH" }, updatedAt: "2026-11-01T11:59:00Z" })])), now), true);
});

test("needsAttention: yours when actionable, anyone's when your review is asked", () => {
  const mine = (o) => ({ ...gh.prModel(pr(o)), reviewRequested: false });
  assert.equal(gh.needsAttention(mine({ mergeStateStatus: "BEHIND" }), "me"), true);
  assert.equal(gh.needsAttention(mine({ reviewDecision: "CHANGES_REQUESTED", mergeStateStatus: "BLOCKED" }), "me"), true);
  assert.equal(gh.needsAttention(mine({ mergeStateStatus: "BLOCKED" }), "me"), false);
  assert.equal(gh.needsAttention({ ...gh.prModel(pr({ author: { login: "dependabot" }, mergeStateStatus: "BEHIND" })), reviewRequested: false }, "me"), false);
  assert.equal(gh.needsAttention({ ...gh.prModel(pr({ author: { login: "them" } })), reviewRequested: true }, "me"), true);
});

test("parseBoard tells per-repo errors from request-level ones and marks review requests", () => {
  const json = {
    data: { review: { nodes: [{ number: 7, repository: { nameWithOwner: "a/b" } }] }, r0: repo(), r1: null, r2: null },
    errors: [{ type: "NOT_FOUND", path: ["r1"], message: "gone" }, { type: "RESOURCE_LIMITS_EXCEEDED", path: ["r2"], message: "slow" }],
  };
  const out = gh.parseBoard(json, { r0: "a/b", r1: "c/d", r2: "e/f" });
  assert.equal(out.repos["a/b"].prs[0].reviewRequested, true);
  assert.equal(out.repos["c/d"].transient, false);
  assert.equal(out.repos["e/f"].transient, true);
  assert.equal(gh.parseBoard({ errors: [{ message: "502" }] }, { r0: "a/b" }).repos["a/b"].transient, true);
});

test("checksModel counts the contexts it did not read", () => {
  const list = gh.checksModel([{ __typename: "StatusContext", context: "x", state: "SUCCESS" }], 140);
  assert.equal(list.more, 139);
  assert.match(gh.agentPrompt("a/b", gh.prModel(pr()), list), /more than were read/);
});

test("itemLink", () => {
  assert.deepEqual(gh.itemLink("https://github.com/a/b/pull/12#discussion"), { repo: "a/b", kind: "pr", number: 12 });
  assert.deepEqual(gh.itemLink("https://github.com/a/b/issues/3"), { repo: "a/b", kind: "issue", number: 3 });
  assert.equal(gh.itemLink("https://github.com/a/b/actions/runs/3"), null);
});

test("prDetailQuery passes the repo and number as variables", () => {
  const q = gh.prDetailQuery("a/b", "12");
  assert.deepEqual(q.variables, { owner: "a", name: "b", number: 12 });
  assert.match(q.query, /isRequired\(pullRequestNumber: \$number\)/);
});

test("mutations pass GitHub text as variables, with the head oid", () => {
  const p = gh.prModel(pr({ id: 'PR_"x', headRefOid: "abc" }));
  const m = gh.mergeMutation(p, "SQUASH");
  assert.deepEqual(m.variables, { id: 'PR_"x', method: "SQUASH", oid: "abc" });
  assert.doesNotMatch(m.query, /PR_/);
  assert.match(gh.autoMergeMutation(p, false).query, /disablePullRequestAutoMerge/);
  assert.match(gh.updateBranchMutation(p).query, /updateMethod: MERGE/);
  assert.equal(gh.commentMutation("I_1", "a\ud800b").variables.body, "a\ud800b");
});

test("parseBoard flags rate limiting and a failed review search", () => {
  const out = gh.parseBoard({ data: { r0: repo(), review: null }, errors: [{ type: "RATE_LIMITED", message: "slow down" }, { path: ["review"], message: "search broke" }] }, { r0: "a/b" });
  assert.equal(out.limited, true);
  assert.equal(out.reviewError, "search broke");
  assert.equal(out.repos["a/b"].prs.length, 1);
});

test("mergeAction", () => {
  const p = (o, can = {}) => ({ ...gh.prModel(pr(o)), can: { admin: false, ...can } });
  assert.equal(gh.mergeAction(p({ mergeStateStatus: "UNSTABLE" })), "Merge");
  assert.equal(gh.mergeAction(p({ mergeStateStatus: "BLOCKED" })), null);
  assert.equal(gh.mergeAction(p({ mergeStateStatus: "BLOCKED" }, { admin: true })), "Admin merge");
  assert.equal(gh.mergeAction(p({ mergeable: "UNKNOWN", mergeStateStatus: "UNKNOWN" }, { admin: true })), null);
  assert.equal(gh.mergeAction(p({ isDraft: true }, { admin: true })), null);
});
