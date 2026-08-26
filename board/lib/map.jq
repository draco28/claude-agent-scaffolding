# map.jq — project-state.json -> desired board. Pure data; no side effects.
def em: " — ";                                   # U+2014 with spaces: the title key separator
def issue_status: if . == "closed" then "complete" else . end;
def milestone_status:
  {planned:"planned", active:"in-progress", complete:"completed", closed:"completed", abandoned:"canceled"}[.] // "planned";
def lines: map(select(. != null and . != "")) | join("\n");

{
  project: .project.name,
  milestones: [ .releases[] | {
    key: .id,
    title: (.id + em + .name),
    status: (.status | milestone_status),
    target_ms: ((.created_at | fromdateiso8601) * 1000),
    description: ([ "goal: " + (.goal // ""), "", "exit criteria:" ] + [ (.exit_criteria // [])[] | "- " + . ] | lines)
  } ],
  issues: (
    [ .spines[] | {
        key: .id, title: (.id + em + .name), task_type: "Spine",
        status: (.status | issue_status), milestone_key: .release, parent_key: null,
        label: ("spine:" + (.class // "unknown")),
        description: ([ "class: " + (.class // ""), "target_repo: " + (.target_repo // "") ] | lines)
    } ]
    + [ .work_items[] | {
        key: .id, title: (.id + em + .title), task_type: "Work item",
        status: (.status | issue_status), milestone_key: null, parent_key: .spine, label: null,
        description: ([ "branch: " + (.branch // ""), "worktree: " + (.worktree_path // ""), "base_sha: " + (.base_sha // "") ] | lines)
    } ]
  ),
  relations: [ .releases[] | (.spine_dag // [])[] | . as [$id, $deps] | ($deps // [])[] | {from_key: $id, to_key: .} ]
}
