#!/bin/sh

set -eu

case $0 in
    */*) script_dir=${0%/*} ;;
    *) script_dir=. ;;
esac

ROOT=$(CDPATH= cd -- "${script_dir}/.." && pwd)
workflow=${ROOT}/.github/workflows/docker-image.yml

fail() {
    printf 'workflow-contract: FAIL: %s\n' "$*" >&2
    exit 1
}

assert_contains() {
    pattern=$1
    file=$2
    grep -F -- "$pattern" "$file" >/dev/null || fail "missing: ${pattern}"
}

assert_not_contains() {
    pattern=$1
    file=$2
    if grep -F -- "$pattern" "$file" >/dev/null; then
        fail "forbidden content: ${pattern}"
    fi
}

assert_count() {
    expected=$1
    pattern=$2
    file=$3
    actual=$(grep -F -c -- "$pattern" "$file" || true)
    [ "$actual" -eq "$expected" ] \
        || fail "expected ${expected} occurrence(s) of '${pattern}', found ${actual}"
}

assert_exact_line() {
    expected=$1
    line=$2
    file=$3
    actual=$(grep -F -x -c -- "$line" "$file" || true)
    [ "$actual" -eq "$expected" ] \
        || fail "expected ${expected} exact line(s) '${line}', found ${actual}"
}

job_block() {
    job=$1
    awk -v job="$job" '
        $0 == "  " job ":" { in_job=1 }
        in_job && /^  [a-zA-Z0-9_-]+:$/ && $0 != "  " job ":" { exit }
        in_job { print }
    ' "$workflow"
}

trigger_block() {
    event=$1
    awk -v event="$event" '
        $0 == "  " event ":" { in_event=1 }
        in_event && /^  [a-zA-Z0-9_-]+:$/ && $0 != "  " event ":" { exit }
        in_event && /^[^[:space:]]/ { exit }
        in_event { print }
    ' "$workflow"
}

assert_block_contains() {
    description=$1
    block=$2
    pattern=$3
    case $block in
        *"$pattern"*) ;;
        *) fail "${description} missing: ${pattern}" ;;
    esac
}

assert_block_not_contains() {
    description=$1
    block=$2
    pattern=$3
    case $block in
        *"$pattern"*) fail "${description} contains forbidden content: ${pattern}" ;;
        *) ;;
    esac
}

assert_block_count() {
    description=$1
    expected=$2
    block=$3
    pattern=$4
    actual=$(printf '%s\n' "$block" | grep -F -c -- "$pattern" || true)
    [ "$actual" -eq "$expected" ] \
        || fail "${description} expected ${expected} occurrence(s) of '${pattern}', found ${actual}"
}

line_in_block() {
    block=$1
    pattern=$2
    line=$(printf '%s\n' "$block" | grep -n -F -- "$pattern" | sed -n '1s/:.*//p')
    [ -n "$line" ] || fail "missing ordering marker: ${pattern}"
    printf '%s\n' "$line"
}

assert_block_before() {
    description=$1
    block=$2
    first_pattern=$3
    second_pattern=$4
    first=$(line_in_block "$block" "$first_pattern")
    second=$(line_in_block "$block" "$second_pattern")
    [ "$first" -lt "$second" ] \
        || fail "${description}: '${first_pattern}' must precede '${second_pattern}'"
}

[ -f "$workflow" ] || fail "missing workflow: ${workflow}"

job_names=$(awk '
    $0 == "jobs:" { in_jobs=1; next }
    in_jobs && /^[^[:space:]]/ { exit }
    in_jobs && /^  [a-zA-Z0-9_-]+:$/ {
        name=$0
        sub(/^  /, "", name)
        sub(/:$/, "", name)
        print name
    }
' "$workflow")

expected_job_names='source-contract
build-test
publish'
[ "$job_names" = "$expected_job_names" ] \
    || fail "top-level jobs must be exactly source-contract, build-test, and publish"

source_block=$(job_block source-contract)
build_block=$(job_block build-test)
publish_block=$(job_block publish)

[ -n "$source_block" ] || fail "missing source-contract job"
[ -n "$build_block" ] || fail "missing build-test job"
[ -n "$publish_block" ] || fail "missing publish job"

permissions_block=$(awk '
    $0 == "permissions:" { in_permissions=1 }
    in_permissions && NR > 1 && /^[^[:space:]]/ && $0 != "permissions:" { exit }
    in_permissions { print }
' "$workflow")
expected_permissions_block='permissions:
  contents: read'
[ "$permissions_block" = "$expected_permissions_block" ] \
    || fail "global permissions block must be exactly contents: read"
assert_count 1 'permissions:' "$workflow"

push_block=$(trigger_block push)
pull_request_block=$(trigger_block pull_request)
[ -n "$push_block" ] || fail "missing push trigger"
[ -n "$pull_request_block" ] || fail "missing pull_request trigger"

for path in \
    Dockerfile \
    docker-entrypoint.sh \
    'dependencies/**' \
    'tests/**' \
    README.md \
    CLAUDE.md \
    '.github/workflows/docker-image.yml'
do
    assert_count 2 "- '${path}'" "$workflow"
    assert_block_contains push-trigger "$push_block" "- '${path}'"
    assert_block_contains pull-request-trigger "$pull_request_block" "- '${path}'"
done

assert_contains 'push:' "$workflow"
assert_contains 'pull_request:' "$workflow"

checkout_pin='uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd'
qemu_pin='uses: docker/setup-qemu-action@06116385d9baf250c9f4dcb4858b16962ea869c3'
qemu_image='docker.io/tonistiigi/binfmt:qemu-v10.2.3@sha256:400a4873b838d1b89194d982c45e5fb3cda4593fbfd7e08a02e76b03b21166f0'
buildx_pin='uses: docker/setup-buildx-action@d7f5e7f509e45cec5c76c4d5afdd7de93d0b3df5'
buildkit_image='moby/buildkit:v0.31.1@sha256:6b59b7df63a8cb9902736f9ddf7fcff8261613d3e7449b8ea8b7537fc399c03a'
login_pin='uses: docker/login-action@4907a6ddec9925e35a0a9e82d7399ccc52663121'
upload_pin='uses: actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a'

assert_count 3 "$checkout_pin" "$workflow"
assert_count 3 'persist-credentials: false' "$workflow"
assert_count 2 "$qemu_pin" "$workflow"
assert_count 2 "          image: ${qemu_image}" "$workflow"
assert_count 2 'platforms: arm64' "$workflow"
assert_count 2 "$buildx_pin" "$workflow"
assert_count 2 'version: v0.35.0' "$workflow"
assert_count 2 "image=${buildkit_image}" "$workflow"
assert_count 1 "$login_pin" "$workflow"
assert_count 1 "$upload_pin" "$workflow"
assert_count 9 'uses:' "$workflow"
assert_count 1 'environment:' "$workflow"
assert_count 2 'secrets' "$workflow"
assert_count 1 'secrets.DOCKER_USERNAME' "$workflow"
assert_count 1 'secrets.DOCKER_PASSWORD' "$workflow"
assert_not_contains 'actions/checkout@v' "$workflow"
assert_not_contains 'docker/setup-qemu-action@v' "$workflow"
assert_not_contains 'docker/setup-buildx-action@v' "$workflow"
assert_not_contains 'docker/login-action@v' "$workflow"
assert_not_contains 'actions/upload-artifact@v' "$workflow"
assert_not_contains 'yq' "$workflow"
assert_not_contains 'sort -V' "$workflow"

assert_block_not_contains source-contract "$source_block" 'needs:'
assert_block_contains source-contract "$source_block" 'runs-on: ubuntu-24.04'
assert_block_contains source-contract "$source_block" "$checkout_pin"
assert_block_contains source-contract "$source_block" 'persist-credentials: false'
assert_block_contains source-contract "$source_block" 'sh -n tests/*.sh'
assert_block_contains source-contract "$source_block" 'tests/source-contract.sh'
assert_block_contains source-contract "$source_block" 'tests/workflow-contract.sh'

for forbidden in 'environment:' 'secrets' 'login-action' '--push' 'push-by-digest' 'push=true' 'type=registry' 'docker push' 'imagetools create'; do
    assert_block_not_contains source-contract "$source_block" "$forbidden"
done

assert_block_contains build-test "$build_block" 'needs: source-contract'
assert_block_contains build-test "$build_block" 'runs-on: ubuntu-24.04'
assert_block_contains build-test "$build_block" 'fail-fast: false'
assert_block_count build-test 2 "$build_block" '- platform:'
assert_block_count build-test 1 "$build_block" '- platform: linux/amd64'
assert_block_count build-test 1 "$build_block" 'arch: amd64'
assert_block_count build-test 1 "$build_block" '- platform: linux/arm64'
assert_block_count build-test 1 "$build_block" 'arch: arm64'
assert_block_contains build-test "$build_block" "$checkout_pin"
assert_block_contains build-test "$build_block" "$qemu_pin"
assert_block_contains build-test "$build_block" "image: ${qemu_image}"
assert_block_contains build-test "$build_block" 'platforms: arm64'
assert_block_contains build-test "$build_block" "$buildx_pin"
assert_block_contains build-test "$build_block" 'version: v0.35.0'
assert_block_contains build-test "$build_block" "image=${buildkit_image}"
assert_block_contains build-test "$build_block" 'verify-${GITHUB_RUN_ID}-${GITHUB_RUN_ATTEMPT}-${{ matrix.arch }}'
assert_block_contains build-test "$build_block" 'docker buildx build --platform "${{ matrix.platform }}" --load -t "$image" .'
assert_block_contains build-test "$build_block" "--format '{{.Os}}/{{.Architecture}}'"
assert_block_contains build-test "$build_block" 'tests/image-contract.sh "$image" "${{ matrix.platform }}"'
assert_block_contains build-test "$build_block" 'tests/inventory-contract.sh "$image" "${{ matrix.platform }}"'

for forbidden in 'environment:' 'secrets' 'login-action' '--push' 'push-by-digest' 'push=true' 'type=registry' 'docker push' 'imagetools create'; do
    assert_block_not_contains build-test "$build_block" "$forbidden"
done

publish_condition="    if: github.event_name == 'push' && github.ref == 'refs/heads/main'"
assert_exact_line 1 "$publish_condition" "$workflow"
assert_block_contains publish "$publish_block" "$publish_condition"
assert_block_contains publish "$publish_block" 'needs: [source-contract, build-test]'
assert_block_contains publish "$publish_block" 'environment: build-image'
assert_block_contains publish "$publish_block" 'runs-on: ubuntu-24.04'
assert_block_contains publish "$publish_block" 'group: openresty-release-main'
assert_block_contains publish "$publish_block" 'cancel-in-progress: false'
assert_block_contains publish "$publish_block" 'docker_config="$RUNNER_TEMP/docker-config"'
assert_block_contains publish "$publish_block" 'DOCKER_CONFIG=%s\n'
assert_block_contains publish "$publish_block" '>> "$GITHUB_ENV"'
assert_block_contains publish "$publish_block" "$checkout_pin"
assert_block_contains publish "$publish_block" "$qemu_pin"
assert_block_contains publish "$publish_block" "$buildx_pin"
assert_block_contains publish "$publish_block" "$login_pin"
assert_block_contains publish "$publish_block" 'username: ${{ secrets.DOCKER_USERNAME }}'
assert_block_contains publish "$publish_block" 'password: ${{ secrets.DOCKER_PASSWORD }}'
assert_block_contains publish "$publish_block" "$upload_pin"
assert_block_contains publish "$publish_block" 'retention-days: 90'

assert_block_count publish 2 "$publish_block" 'git ls-remote https://github.com/iYism/docker-openresty.git refs/heads/main'
assert_block_count publish 2 "$publish_block" 'test "$remote_head" = "$GITHUB_SHA"'
assert_block_contains publish "$publish_block" 'candidate-${GITHUB_RUN_ID}-${GITHUB_RUN_ATTEMPT}'
assert_block_count publish 1 "$publish_block" 'push-by-digest=true,name-canonical=true,push=true'
assert_block_count publish 1 "$publish_block" '--provenance=false'
assert_block_count publish 1 "$publish_block" '--sbom=false'
assert_block_count publish 1 "$publish_block" '.["containerimage.digest"]'
assert_block_count publish 1 "$publish_block" '.["containerimage.descriptor"].digest'
assert_block_not_contains publish "$publish_block" '.["containerimage.descriptor.digest"]'
assert_block_contains publish "$publish_block" "digest=\$(jq -er '.[\"containerimage.digest\"]"
assert_block_contains publish "$publish_block" "index_digest=\$(jq -er '.[\"containerimage.descriptor\"].digest"
assert_block_contains publish "$publish_block" 'immutable="${REPO}@${digest}"'
assert_block_contains publish "$publish_block" '"${REPO}@${AMD64_DIGEST}"'
assert_block_contains publish "$publish_block" '"${REPO}@${ARM64_DIGEST}"'
assert_block_contains publish "$publish_block" "descriptor_count=\$(jq -er '.manifests | length'"
assert_block_contains publish "$publish_block" 'test "$descriptor_count" -eq 2'
assert_block_contains publish "$publish_block" 'linux/amd64=${AMD64_DIGEST}'
assert_block_contains publish "$publish_block" 'linux/arm64=${ARM64_DIGEST}'
assert_block_contains publish "$publish_block" 'tests/image-contract.sh "$immutable" "$platform"'
assert_block_contains publish "$publish_block" 'tests/inventory-contract.sh "$immutable" "$platform"'
assert_block_contains publish "$publish_block" 'tests/image-contract.sh "$IMMUTABLE_INDEX" "$platform"'
assert_block_contains publish "$publish_block" 'tests/inventory-contract.sh "$IMMUTABLE_INDEX" "$platform"'

assert_block_contains publish "$publish_block" 'OPENRESTY_VERSION: ${{ vars.OPENRESTY_VERSION }}'
assert_block_contains publish "$publish_block" 'test "$OPENRESTY_VERSION" = "1.31.1.1"'
assert_block_contains publish "$publish_block" 'configured OpenResty version must equal locked version 1.31.1.1'
assert_block_contains publish "$publish_block" 'events-${RESTY_EVENTS_VERSION}-sha256-'
assert_block_contains publish "$publish_block" 'if existing_digest=$(docker buildx imagetools inspect "$release"'
assert_block_contains publish "$publish_block" 'release tag collision'
assert_block_contains publish "$publish_block" 'collision_error="$RUNNER_TEMP/release-tag-inspect.err"'
assert_block_contains publish "$publish_block" "grep -E -q '(manifest unknown|not found)' \"\$collision_error\""
assert_block_contains publish "$publish_block" 'unable to prove release tag absence'
assert_block_contains publish "$publish_block" 'docker buildx imagetools create \'
assert_block_contains publish "$publish_block" '--tag "${REPO}:latest" \'
assert_block_contains publish "$publish_block" '--tag "${REPO}:${VERSION}" \'
assert_block_contains publish "$publish_block" '--tag "$RELEASE" \'
assert_block_contains publish "$publish_block" '"$IMMUTABLE_INDEX"'
assert_block_contains publish "$publish_block" "--format '{{json .Manifest.Digest}}'"
assert_block_contains publish "$publish_block" 'for tag in "${REPO}:latest" "${REPO}:${VERSION}" "$RELEASE"; do'
assert_block_contains publish "$publish_block" 'test "$actual_digest" = "$INDEX_DIGEST"'

assert_block_contains publish "$publish_block" 'release-evidence.json'
assert_block_contains publish "$publish_block" 'source_commit'
assert_block_contains publish "$publish_block" 'workflow_url'
assert_block_contains publish "$publish_block" 'baseline_digest'
assert_block_contains publish "$publish_block" 'top_level_digest'
assert_block_contains publish "$publish_block" 'child_digests'
assert_block_contains publish "$publish_block" 'tag_mappings'
assert_block_contains publish "$publish_block" 'contract_results'
assert_block_contains publish "$publish_block" 'resolved_inputs'
assert_block_contains publish "$publish_block" 'residual_risks'
assert_block_contains publish "$publish_block" 'Rocky Linux base image tags remain floating'
assert_block_contains publish "$publish_block" 'NGX_BROTLI_VER=master remains floating'
assert_block_contains publish "$publish_block" 'the OpenResty patch URL remains floating'
assert_block_contains publish "$publish_block" 'unrelated legacy source archives remain unchecksummed'
assert_block_contains publish "$publish_block" 'DNF repository content remains mutable'
assert_block_contains publish "$publish_block" 'openresty-release-${{ github.run_id }}-${{ github.run_attempt }}'
assert_block_contains publish "$publish_block" 'GITHUB_STEP_SUMMARY'

assert_block_before publish "$publish_block" 'name: Build and test immutable children' 'name: Promote tested index'
assert_block_before publish "$publish_block" 'name: Validate candidate index and rerun contracts' 'name: Promote tested index'
assert_block_before publish "$publish_block" 'name: Recheck main tip before promotion' 'name: Promote tested index'
assert_block_before publish "$publish_block" 'name: Promote tested index' 'name: Write release evidence'
assert_block_before publish "$publish_block" 'name: Isolate Docker credentials' 'name: Set up QEMU'
assert_block_before publish "$publish_block" 'name: Isolate Docker credentials' 'name: Set up Docker Buildx'
assert_block_before publish "$publish_block" 'name: Isolate Docker credentials' 'name: Login to Docker Hub'
assert_block_before publish "$publish_block" 'docker buildx build \' 'name: Promote tested index'
assert_block_before publish "$publish_block" 'tests/image-contract.sh "$immutable" "$platform"' 'name: Promote tested index'
assert_block_before publish "$publish_block" 'tests/inventory-contract.sh "$immutable" "$platform"' 'name: Promote tested index'
assert_block_before publish "$publish_block" 'tests/image-contract.sh "$IMMUTABLE_INDEX" "$platform"' 'name: Promote tested index'
assert_block_before publish "$publish_block" 'tests/inventory-contract.sh "$IMMUTABLE_INDEX" "$platform"' 'name: Promote tested index'

printf 'workflow-contract: PASS\n'
