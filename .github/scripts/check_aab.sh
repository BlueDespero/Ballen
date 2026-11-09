#!/usr/bin/env bash
# Checks an Android App Bundle against what Google Play and the release plan
# (docs/milestones/06-android-release.md) require: package name, target and min
# SDK, version code, no permissions, and 64-bit native libraries aligned to
# 16 KB pages. Prints every problem, then exits 1 if there were any.
#
# Usage: check_aab.sh <bundle.aab> <bundletool.jar> <expected version code>
set -uo pipefail

aab="$1"
bundletool="$2"
expected_code="$3"
package="io.github.bluedespero.ballen"
target_sdk=36
min_sdk=24
problems=0

fail() {
	echo "::error::$1"
	problems=1
}

manifest_value() {
	java -jar "$bundletool" dump manifest --bundle "$aab" --xpath "$1" 2>/dev/null | tr -d '[:space:]'
}

[ -f "$aab" ] || { echo "::error::No bundle at $aab"; exit 1; }

got="$(manifest_value /manifest/@package)"
[ "$got" = "$package" ] || fail "Package is '$got', expected $package (it can never change once uploaded)."

got="$(manifest_value /manifest/uses-sdk/@android:targetSdkVersion)"
[ "$got" = "$target_sdk" ] || fail "Target SDK is '$got'; Google Play requires $target_sdk."

got="$(manifest_value /manifest/uses-sdk/@android:minSdkVersion)"
[ "$got" = "$min_sdk" ] || fail "Min SDK is '$got', expected $min_sdk."

got="$(manifest_value /manifest/@android:versionCode)"
[ "$got" = "$expected_code" ] || fail "Version code is '$got', expected $expected_code."

# AndroidX declares an app-private signature permission for its own receivers;
# it shows no prompt and isn't a permission Play lists. Anything else is.
permissions="$(java -jar "$bundletool" dump manifest --bundle "$aab" 2>/dev/null \
	| grep -o 'uses-permission[^>]*android:name="[^"]*"' \
	| sed -E 's/.*android:name="([^"]*)".*/\1/' \
	| grep -v '\.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION$' || true)"
[ -z "$permissions" ] || fail "The bundle asks for permissions: $(echo "$permissions" | tr '\n' ' ')"

libs="$(mktemp -d)"
unzip -q -o "$aab" 'base/lib/arm64-v8a/*.so' -d "$libs" 2>/dev/null
found=0
for so in "$libs"/base/lib/arm64-v8a/*.so; do
	[ -f "$so" ] || continue
	found=1
	for align in $(readelf -lW "$so" | awk '$1 == "LOAD" {print $NF}'); do
		if [ $((align)) -lt $((0x4000)) ]; then
			fail "$(basename "$so") has a LOAD segment aligned to $align; Play needs 16 KB (0x4000)."
			break
		fi
	done
done
[ "$found" = 1 ] || fail "No arm64-v8a native libraries in the bundle."

if [ "$problems" = 0 ]; then
	echo "Bundle OK: $package, target SDK $target_sdk, min SDK $min_sdk, version code $expected_code, no permissions, 16 KB aligned."
fi
exit "$problems"
