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
  assert.equal(gh.isHot(gh.repoModel(repo())), false);
  assert.equal(gh.isHot(gh.repoModel(repo([pr({ commits: { nodes: [{ commit: { statusCheckRollup: { state: "PENDING" } } }] } })]))), true);
  assert.equal(gh.isHot(gh.repoModel(repo([pr({ mergeable: "UNKNOWN" })]))), true);
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
  assert.deepEqual(gh.dispatchInfo("on:\n  push:\n"), { dispatch: false, requiredInputs: false });
  assert.deepEqual(gh.dispatchInfo("on:\n  workflow_dispatch:\n  push:\n"), { dispatch: true, requiredInputs: false });
  assert.deepEqual(gh.dispatchInfo("on:\n  workflow_dispatch:\n    inputs:\n      v:\n        required: true\n"), { dispatch: true, requiredInputs: true });
  assert.deepEqual(gh.dispatchInfo("on: [push, workflow_dispatch]\n"), { dispatch: true, requiredInputs: false });
});

test("itemLink", () => {
  assert.deepEqual(gh.itemLink("https://github.com/a/b/pull/12#discussion"), { repo: "a/b", kind: "pr", number: 12 });
  assert.deepEqual(gh.itemLink("https://github.com/a/b/issues/3"), { repo: "a/b", kind: "issue", number: 3 });
  assert.equal(gh.itemLink("https://github.com/a/b/actions/runs/3"), null);
});

test("prDetailQuery inlines the number", () => {
  const q = gh.prDetailQuery("a/b", 12);
  assert.match(q, /pullRequest\(number: 12\)/);
  assert.match(q, /isRequired\(pullRequestNumber: 12\)/);
});
