// Pure GitHub data handling: query text, response parsing and derived state.
// Nothing here touches the network or Herdr, so it runs under `node --test`.

export const GRAPHQL = "https://api.github.com/graphql";
export const REST = "https://api.github.com";

const RATE = "rateLimit { cost remaining resetAt }";

// GitHub Actions' app id. Other apps open a check suite per push that can stay
// queued forever, so the default branch's runs are Actions' suites only.
const ACTIONS_APP = 15368;

// Pending or unknown states only make a repository hot while recent: a
// required status nobody reports, or a run waiting for approval, stays
// pending indefinitely and would otherwise be polled fast forever.
const HOT_FOR = 45 * 60 * 1000;

// Poll fields per repository. Check contexts are left out: GraphQL cost follows
// the connection sizes requested, and contexts(first: 50) on every PR multiplies
// it. Rows load them when opened.
const REPO = `
  nameWithOwner url viewerPermission
  squashMergeAllowed mergeCommitAllowed rebaseMergeAllowed autoMergeAllowed
  issues(states: OPEN) { totalCount }
  latestRelease { tagName url publishedAt }
  defaultBranchRef { name target { ... on Commit {
    oid statusCheckRollup { state }
    checkSuites(first: 20, filterBy: { appId: ${ACTIONS_APP} }) { nodes { status conclusion workflowRun {
      databaseId runNumber event url createdAt updatedAt workflow { name } } } }
  } } }
  pullRequests(states: OPEN, first: 30, orderBy: { field: UPDATED_AT, direction: DESC }) {
    totalCount
    nodes {
      id number title url isDraft isCrossRepository updatedAt createdAt
      author { login } headRefName baseRefName headRefOid additions deletions
      mergeable mergeStateStatus reviewDecision
      autoMergeRequest { enabledAt mergeMethod }
      viewerCanMergeAsAdmin viewerCanEnableAutoMerge viewerCanDisableAutoMerge viewerCanUpdateBranch
      commits(last: 1) { nodes { commit { statusCheckRollup { state } } } }
    }
  }`;

export const splitRepo = (full) => {
  const m = /^([\w.-]+)\/([\w.-]+)$/.exec(full.trim());
  return m ? { owner: m[1], name: m[2] } : null;
};

const str = (s) => JSON.stringify(s);

// One aliased query for a set of repositories. GitHub answers per alias, so a
// renamed or forbidden repository becomes an error on its alias, not the request.
// The search finds PRs awaiting the viewer's review in the same request, which
// is cheaper than reading every PR's review requests.
export function boardQuery(repos) {
  const aliases = {};
  const valid = repos.filter((full) => splitRepo(full));
  const parts = repos.map((full, i) => {
    const r = splitRepo(full);
    aliases[`r${i}`] = full;
    return r ? `r${i}: repository(owner: ${str(r.owner)}, name: ${str(r.name)}) {${REPO}}` : "";
  });
  const scope = valid.map((full) => `repo:${full}`).join(" ");
  const review = valid.length
    ? `review: search(type: ISSUE, first: 50, query: ${str(`is:open is:pr review-requested:@me ${scope}`)}) { nodes { ... on PullRequest { number repository { nameWithOwner } } } }`
    : "";
  return { query: `query { viewer { login } ${RATE} ${review} ${parts.join("\n")} }`, aliases };
}

export function chunk(list, size) {
  const out = [];
  for (let i = 0; i < list.length; i += size) out.push(list.slice(i, i + size));
  return out;
}

export function ciState(state) {
  switch (state) {
    case "SUCCESS": return "pass";
    case "FAILURE": case "ERROR": return "fail";
    case "PENDING": case "EXPECTED": return "pending";
    default: return "none";
  }
}

// What stands between a PR and merging, in GitHub's terms. mergeable is
// computed lazily by GitHub and reads UNKNOWN until it has been asked once.
export function mergeState(pr) {
  if (pr.isDraft) return "draft";
  if (pr.mergeable === "CONFLICTING" || pr.mergeStateStatus === "DIRTY") return "conflict";
  if (pr.mergeable === "UNKNOWN" || pr.mergeStateStatus === "UNKNOWN") return "unknown";
  switch (pr.mergeStateStatus) {
    case "BEHIND": return "behind";
    case "BLOCKED": return "blocked";
    case "UNSTABLE": return "unstable";
    case "CLEAN": case "HAS_HOOKS": return "clean";
    default: return "unknown";
  }
}

export function prModel(n) {
  const rollup = n.commits?.nodes?.[0]?.commit?.statusCheckRollup?.state ?? null;
  return {
    id: n.id, number: n.number, title: n.title, url: n.url, author: n.author?.login ?? "ghost",
    draft: n.isDraft, fork: n.isCrossRepository, head: n.headRefName, base: n.baseRefName, oid: n.headRefOid,
    additions: n.additions, deletions: n.deletions, updatedAt: n.updatedAt,
    ci: ciState(rollup), merge: mergeState(n), mergeable: n.mergeable, mergeStatus: n.mergeStateStatus,
    review: n.reviewDecision, auto: n.autoMergeRequest ? n.autoMergeRequest.mergeMethod : null,
    can: {
      admin: Boolean(n.viewerCanMergeAsAdmin), enableAuto: Boolean(n.viewerCanEnableAutoMerge),
      disableAuto: Boolean(n.viewerCanDisableAutoMerge), update: Boolean(n.viewerCanUpdateBranch),
    },
  };
}

export function runModel(suite) {
  const w = suite.workflowRun;
  return {
    id: w.databaseId, number: w.runNumber, name: w.workflow?.name ?? "workflow", event: w.event, url: w.url,
    createdAt: w.createdAt, updatedAt: w.updatedAt,
    state: suite.status === "COMPLETED" ? conclusionState(suite.conclusion) : "pending",
  };
}

export function conclusionState(c) {
  switch ((c ?? "").toUpperCase()) {
    case "SUCCESS": return "pass";
    case "NEUTRAL": case "SKIPPED": return "skip";
    case "CANCELLED": case "STALE": return "cancel";
    case "": return "pending";
    default: return "fail";
  }
}

export function repoModel(node) {
  const head = node.defaultBranchRef?.target ?? null;
  const suites = head?.checkSuites?.nodes ?? [];
  return {
    full: node.nameWithOwner, url: node.url, permission: node.viewerPermission,
    methods: { squash: node.squashMergeAllowed, merge: node.mergeCommitAllowed, rebase: node.rebaseMergeAllowed },
    autoMergeAllowed: node.autoMergeAllowed, issues: node.issues?.totalCount ?? 0,
    release: node.latestRelease ? { tag: node.latestRelease.tagName, url: node.latestRelease.url, at: node.latestRelease.publishedAt } : null,
    branch: node.defaultBranchRef?.name ?? null, branchOid: head?.oid ?? null,
    branchCi: ciState(head?.statusCheckRollup?.state ?? null),
    runs: suites.filter((s) => s.workflowRun).map(runModel).reverse(),
    prs: (node.pullRequests?.nodes ?? []).map(prModel),
    prTotal: node.pullRequests?.totalCount ?? 0,
  };
}

// Splits a GraphQL answer into one model or error per alias. A partial answer
// carries both data and errors; each error's path names the alias it belongs to.
// An error with a type GitHub gives per alias (NOT_FOUND, FORBIDDEN) is about
// that repository; anything else is about the request, and `transient` tells
// the caller to keep what it already shows.
export function parseBoard(json, aliases) {
  const out = { repos: {}, rate: json?.data?.rateLimit ?? null, viewer: json?.data?.viewer?.login ?? null, error: null, reviewError: null, limited: false };
  const byAlias = {};
  for (const e of json?.errors ?? []) {
    const alias = e.path?.[0];
    if (e.type === "RATE_LIMITED") out.limited = true;
    if (alias && alias in aliases) (byAlias[alias] ??= []).push(e);
    else if (alias === "review") out.reviewError = e.message;
    else out.error = (out.error ? out.error + "; " : "") + e.message;
  }
  const review = new Set((json?.data?.review?.nodes ?? []).filter((n) => n?.repository).map((n) => `${n.repository.nameWithOwner}#${n.number}`));
  for (const [alias, full] of Object.entries(aliases)) {
    const node = json?.data?.[alias];
    if (node) {
      const repo = repoModel(node);
      for (const p of repo.prs) p.reviewRequested = review.has(`${repo.full}#${p.number}`);
      out.repos[full] = repo;
    } else if (byAlias[alias]) {
      const errs = byAlias[alias];
      out.repos[full] = { full, error: errs.map((e) => e.message).join("; "), transient: !errs.every((e) => e.type === "NOT_FOUND" || e.type === "FORBIDDEN") };
    } else {
      out.repos[full] = splitRepo(full) ? { full, error: out.error ?? "No data", transient: true } : { full, error: "Not owner/name", transient: false };
    }
  }
  return out;
}

// Polled fast: something on it is about to change by itself.
export function isHot(repo, now = Date.now()) {
  if (!repo || repo.error) return false;
  const recent = (iso) => iso && now - Date.parse(iso) < HOT_FOR;
  return (repo.branchCi === "pending" && repo.runs.some((r) => recent(r.updatedAt ?? r.createdAt)))
    || repo.runs.some((r) => r.state === "pending" && recent(r.updatedAt ?? r.createdAt))
    || repo.prs.some((p) => recent(p.updatedAt) && (p.ci === "pending" || p.merge === "unknown" || (p.auto && p.merge === "clean")));
}

// Yours when something needs doing to it; anyone's when your review is asked for.
export function needsAttention(pr, viewer) {
  if (pr.reviewRequested) return true;
  if (pr.draft || pr.author !== viewer) return false;
  return pr.ci === "fail" || pr.merge === "conflict" || pr.merge === "behind"
    || pr.review === "CHANGES_REQUESTED" || (pr.merge === "clean" && !pr.auto);
}

export function mergeMethod(methods) {
  if (methods?.squash) return "SQUASH";
  if (methods?.merge) return "MERGE";
  if (methods?.rebase) return "REBASE";
  return "SQUASH";
}

// One PR in full, for an opened row or an item pane.
export function prDetailQuery(full, number) {
  const r = splitRepo(full);
  return {
    query: `query($owner: String!, $name: String!, $number: Int!) { ${RATE} repository(owner: $owner, name: $name) {
      squashMergeAllowed mergeCommitAllowed rebaseMergeAllowed
      pullRequest(number: $number) { ${PR_DETAIL} } } }`,
    variables: { owner: r?.owner ?? "", name: r?.name ?? "", number: Number(number) },
  };
}

const PR_DETAIL = `
  id number title url body isDraft isCrossRepository state merged closed createdAt updatedAt
  author { login } headRefName baseRefName headRefOid additions deletions changedFiles
  mergeable mergeStateStatus reviewDecision autoMergeRequest { enabledAt mergeMethod }
  viewerCanMergeAsAdmin viewerCanEnableAutoMerge viewerCanDisableAutoMerge viewerCanUpdateBranch
  labels(first: 10) { nodes { name color } }
  reviewRequests(first: 10) { nodes { requestedReviewer { ... on User { login } ... on Team { name } } } }
  commits(last: 1) { nodes { commit { oid messageHeadline statusCheckRollup { state contexts(first: 100) { totalCount pageInfo { hasNextPage } nodes {
    __typename
    ... on CheckRun { name status conclusion detailsUrl isRequired(pullRequestNumber: $number) checkSuite { workflowRun { databaseId } app { slug } } }
    ... on StatusContext { context state targetUrl isRequired(pullRequestNumber: $number) }
  } } } } } }
  timelineItems(last: 40, itemTypes: [ISSUE_COMMENT, PULL_REQUEST_REVIEW, PULL_REQUEST_COMMIT, HEAD_REF_FORCE_PUSHED_EVENT, MERGED_EVENT, CLOSED_EVENT, REOPENED_EVENT]) { nodes {
    __typename
    ... on IssueComment { author { login } body createdAt url }
    ... on PullRequestReview { author { login } body state createdAt url }
    ... on PullRequestCommit { commit { oid messageHeadline committedDate author { user { login } name } } }
    ... on HeadRefForcePushedEvent { actor { login } createdAt }
    ... on MergedEvent { actor { login } createdAt }
    ... on ClosedEvent { actor { login } createdAt }
    ... on ReopenedEvent { actor { login } createdAt }
  } }`;

export function checkModel(c) {
  if (c.__typename === "StatusContext") {
    return { name: c.context, state: statusState(c.state), url: c.targetUrl, required: Boolean(c.isRequired), run: null, app: "status" };
  }
  return {
    name: c.name, url: c.detailsUrl, required: Boolean(c.isRequired),
    state: c.status === "COMPLETED" ? conclusionState(c.conclusion) : "pending",
    run: c.checkSuite?.workflowRun?.databaseId ?? null, app: c.checkSuite?.app?.slug ?? null,
  };
}

function statusState(s) {
  switch (s) {
    case "SUCCESS": return "pass";
    case "PENDING": case "EXPECTED": return "pending";
    default: return "fail";
  }
}

const ORDER = { fail: 0, pending: 1, cancel: 2, pass: 3, skip: 4 };

// `more`: GitHub had more contexts than were read, so failures may be missing.
export function checksModel(contexts, total = 0) {
  const list = (contexts ?? []).map(checkModel).sort((a, b) => ORDER[a.state] - ORDER[b.state] || a.name.localeCompare(b.name));
  list.more = Math.max(0, total - list.length);
  return list;
}

// Failed checks split by whether a rerun can reach them: only GitHub Actions
// check runs have a workflow run; other apps' checks and commit statuses don't.
export function rerunPlan(checks) {
  const failed = checks.filter((c) => c.state === "fail" || c.state === "cancel");
  const runs = [...new Set(failed.filter((c) => c.run).map((c) => c.run))];
  return { runs, stuck: failed.filter((c) => !c.run).map((c) => c.name) };
}

export function prDetailModel(json) {
  const repo = json?.data?.repository;
  const p = repo?.pullRequest;
  if (!p) return null;
  const commit = p.commits?.nodes?.[0]?.commit;
  return {
    ...prModel({ ...p, commits: { nodes: [{ commit }] } }),
    body: p.body ?? "", state: p.merged ? "merged" : p.closed ? "closed" : "open",
    changedFiles: p.changedFiles, createdAt: p.createdAt,
    methods: { squash: repo.squashMergeAllowed, merge: repo.mergeCommitAllowed, rebase: repo.rebaseMergeAllowed },
    labels: (p.labels?.nodes ?? []).map((l) => ({ name: l.name, color: l.color })),
    reviewers: (p.reviewRequests?.nodes ?? []).map((r) => r.requestedReviewer?.login ?? r.requestedReviewer?.name).filter(Boolean),
    headline: commit?.messageHeadline ?? "",
    checks: checksModel(commit?.statusCheckRollup?.contexts?.nodes, commit?.statusCheckRollup?.contexts?.totalCount),
    timeline: (p.timelineItems?.nodes ?? []).map(timelineModel).filter(Boolean),
  };
}

export function timelineModel(n) {
  switch (n.__typename) {
    case "IssueComment": return { kind: "comment", who: n.author?.login ?? "ghost", body: n.body, at: n.createdAt, url: n.url };
    case "PullRequestReview": return { kind: "review", who: n.author?.login ?? "ghost", body: n.body, state: n.state, at: n.createdAt, url: n.url };
    case "PullRequestCommit": return { kind: "commit", who: n.commit.author?.user?.login ?? n.commit.author?.name ?? "", body: n.commit.messageHeadline, oid: n.commit.oid, at: n.commit.committedDate };
    case "HeadRefForcePushedEvent": return { kind: "event", who: n.actor?.login ?? "", body: "force-pushed", at: n.createdAt };
    case "MergedEvent": return { kind: "event", who: n.actor?.login ?? "", body: "merged", at: n.createdAt };
    case "ClosedEvent": return { kind: "event", who: n.actor?.login ?? "", body: "closed", at: n.createdAt };
    case "ReopenedEvent": return { kind: "event", who: n.actor?.login ?? "", body: "reopened", at: n.createdAt };
    default: return null;
  }
}

// The brief for an agent sent to get a PR mergeable. It names what is wrong
// now, so the agent does not have to rediscover it.
export function agentPrompt(full, pr, checks) {
  const lines = [`Get ${full}#${pr.number} (${pr.url}) mergeable. Branch ${pr.head}, base ${pr.base}.`];
  lines.push(`First run \`git fetch origin && git merge --ff-only origin/${pr.head}\` and confirm HEAD is ${pr.oid}; stop and say so if it is not.`);
  if (pr.merge === "conflict") lines.push(`It conflicts with ${pr.base}: merge origin/${pr.base} in (do not rebase) and resolve the conflicts.`);
  else if (pr.merge === "behind") lines.push(`It is behind ${pr.base}: merge origin/${pr.base} in (do not rebase).`);
  const { runs, stuck } = rerunPlan(checks ?? []);
  const failing = (checks ?? []).filter((c) => c.state === "fail");
  if (!failing.length && checks?.more) lines.push(`Some checks may be failing; there are more than were read, so see the PR page.`);
  if (failing.length) {
    lines.push(`Failing checks: ${failing.map((c) => c.name).join(", ")}.`);
    if (runs.length) lines.push(`Read their logs with ${runs.map((id) => `\`gh run view ${id} -R ${full} --log-failed\``).join(", ")}.`);
    if (stuck.length) lines.push(`Not from GitHub Actions (see the PR page): ${stuck.join(", ")}.`);
    if (checks.more) lines.push(`There are more checks than listed here; see the PR page for the rest.`);
    lines.push("Fix the causes rather than the tests' expectations, unless the expectation is what is wrong.");
  }
  lines.push("Commit, push, and check CI passes.");
  return lines.join(" ");
}

// Which workflows can be started by hand, from their YAML. There is no YAML
// parser here, so inputs are only a hint: Run is offered either way and
// GitHub's refusal, if any, is shown.
export function dispatchInfo(yaml) {
  const text = yaml ?? "";
  const dispatch = /^\s*(-\s*)?workflow_dispatch\s*:?\s*(#.*)?$/m.test(text)
    || /^["']?on["']?\s*:\s*workflow_dispatch\b/m.test(text)
    || /^["']?on["']?\s*:\s*\[[^\]]*workflow_dispatch/m.test(text);
  return { dispatch, inputs: dispatch && dispatchBlock(text).some((l) => /^\s*inputs\s*:/.test(l)) };
}

// The lines indented under `workflow_dispatch:`.
function dispatchBlock(text) {
  const lines = text.split("\n"), at = lines.findIndex((l) => /^\s*workflow_dispatch\s*:/.test(l));
  if (at < 0) return [];
  const indent = /^\s*/.exec(lines[at])[0].length, out = [];
  for (const l of lines.slice(at + 1)) {
    if (l.trim() && /^\s*/.exec(l)[0].length <= indent) break;
    out.push(l);
  }
  return out;
}

export function workflowsQuery(full) {
  const r = splitRepo(full);
  return { variables: { owner: r?.owner ?? "", name: r?.name ?? "" }, query: `query($owner: String!, $name: String!) { ${RATE} repository(owner: $owner, name: $name) {
    defaultBranchRef { name }
    object(expression: "HEAD:.github/workflows") { ... on Tree { entries { name path object { ... on Blob { text } } } } }
    releases(first: 10, orderBy: { field: CREATED_AT, direction: DESC }) { nodes { tagName name url publishedAt isPrerelease isDraft } }
  } }` };
}

export function releasesModel(json) {
  return (json?.data?.repository?.releases?.nodes ?? []).map((r) => ({
    tag: r.tagName, name: r.name || r.tagName, url: r.url, at: r.publishedAt, prerelease: r.isPrerelease, draft: r.isDraft,
  }));
}

export function workflowsModel(json) {
  const entries = json?.data?.repository?.object?.entries ?? [];
  return entries.filter((e) => /\.ya?ml$/.test(e.name)).map((e) => {
    const text = e.object?.text ?? "";
    const name = /^name\s*:\s*["']?(.+?)["']?\s*(#.*)?$/m.exec(text)?.[1] ?? e.name;
    return { file: e.name, path: e.path, name, ...dispatchInfo(text) };
  });
}

// `tags`: the repository's release tags, since a tag push's head_branch is the tag.
export function restRunModel(r, tags = new Set()) {
  return {
    id: r.id, number: r.run_number, name: r.name ?? r.display_title, title: r.display_title, event: r.event,
    branch: r.head_branch, sha: r.head_sha, url: r.html_url, createdAt: r.created_at, updatedAt: r.updated_at,
    state: r.status === "completed" ? conclusionState(r.conclusion) : "pending", actor: r.actor?.login ?? "",
    release: r.event === "release" || tags.has(r.head_branch) || (r.event !== "pull_request" && /release|publish/i.test(r.path ?? "")),
  };
}

export function age(iso, now = Date.now()) {
  if (!iso) return "";
  const s = Math.max(0, Math.round((now - Date.parse(iso)) / 1000));
  if (s < 60) return `${s}s`;
  if (s < 3600) return `${Math.floor(s / 60)}m`;
  if (s < 86400) return `${Math.floor(s / 3600)}h`;
  return `${Math.floor(s / 86400)}d`;
}

// github.com links that have a view here: a PR or an issue.
export function itemLink(url) {
  const m = /^https:\/\/github\.com\/([\w.-]+\/[\w.-]+)\/(pull|issues)\/(\d+)(?:[/?#].*)?$/.exec(url ?? "");
  return m ? { repo: m[1], kind: m[2] === "pull" ? "pr" : "issue", number: Number(m[3]) } : null;
}

// Mutations carry the head commit shown on screen, so a push that lands
// between looking and clicking fails the action instead of merging unseen code.
export function mergeMutation(pr, method) {
  return { query: `mutation($id: ID!, $method: PullRequestMergeMethod!, $oid: GitObjectID!) {
    mergePullRequest(input: { pullRequestId: $id, mergeMethod: $method, expectedHeadOid: $oid }) { pullRequest { merged } } }`,
    variables: { id: pr.id, method, oid: pr.oid } };
}

export function autoMergeMutation(pr, enable, method) {
  return enable
    ? { query: `mutation($id: ID!, $method: PullRequestMergeMethod!, $oid: GitObjectID!) {
        enablePullRequestAutoMerge(input: { pullRequestId: $id, mergeMethod: $method, expectedHeadOid: $oid }) { clientMutationId } }`,
      variables: { id: pr.id, method, oid: pr.oid } }
    : { query: `mutation($id: ID!) { disablePullRequestAutoMerge(input: { pullRequestId: $id }) { clientMutationId } }`, variables: { id: pr.id } };
}

export function updateBranchMutation(pr) {
  return { query: `mutation($id: ID!, $oid: GitObjectID!) {
    updatePullRequestBranch(input: { pullRequestId: $id, expectedHeadOid: $oid, updateMethod: MERGE }) { clientMutationId } }`,
    variables: { id: pr.id, oid: pr.oid } };
}

export function readyMutation(pr) {
  return { query: `mutation($id: ID!) { markPullRequestReadyForReview(input: { pullRequestId: $id }) { clientMutationId } }`, variables: { id: pr.id } };
}

export function commentMutation(subjectId, body) {
  return { query: `mutation($id: ID!, $body: String!) { addComment(input: { subjectId: $id, body: $body }) { clientMutationId } }`, variables: { id: subjectId, body } };
}

export const viewerReposQuery = `query { viewer { repositories(first: 100, orderBy: { field: PUSHED_AT, direction: DESC }, affiliations: [OWNER, COLLABORATOR, ORGANIZATION_MEMBER], isArchived: false) { nodes { nameWithOwner } } } }`;
