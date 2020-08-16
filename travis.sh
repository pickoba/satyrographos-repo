#!/bin/bash
# vim: set et fenc=utf-8 ff=unix sts=0 sw=4 ts=4 : 

set -ex

if [ "$TRAVIS_PULL_REQUEST" != "false" ]; then
    echo "Pull request"
else
    echo "Non pull request"
fi

export PACKAGE="$SNAPSHOT"
bash -ex .travis-opam.sh

opam --version

FAILED_PACKAGES=failed.pkgs
: > "$FAILED_PACKAGES"

if [ "$TRAVIS_PULL_REQUEST" != "false" ]; then
    echo "Pull request"

    eval $(opam config env)

    sed -i.bak -e '/^# Package List$/,/^# Package List End$/d' "$SNAPSHOT".opam
    opam update

    export OPAMYES=1
    git diff --name-status master | sed -e '/^D/d' -e 's/^\w*\s//' -e '/^packages\//!d' -e 's!\([^/]*/\)\{2\}!!' -e 's!/.*!!' | sort | uniq \
        | while read PACKAGE ; do
            PACKAGE_NAME="${PACKAGE%%.*}"
            SATYSFI_PACKAGE="satysfi.$(opam show -f version satysfi)"

            declare -a PACKAGES_AND_OPTIONS=('--strict' '--with-test' "$SATYSFI_PACKAGE" "$SNAPSHOT" "$PACKAGE")

            if ! opam install --json=opam-output.json --dry-run --unlock-base "${PACKAGES_AND_OPTIONS[@]}"
            then
                echo "Assuming dependency does not meet. Skipping"
                continue

                if jq -e '.conflicts["causes"] | index("No available version of satysfi satisfies the constraints")' opam-output.json
                then
                    echo "Dependency does not meet. Skipping"
                    continue
                else
                    echo "$PACKAGE: dependency" >> "$FAILED_PACKAGES"
                    continue
                fi
            fi

            if ! opam install "${PACKAGES_AND_OPTIONS[@]}"
            then
                echo "$PACKAGE: install" >> "$FAILED_PACKAGES"
                continue
            elif ! opam uninstall "$PACKAGE"
            then
                echo "$PACKAGE: uninstall" >> "$FAILED_PACKAGES"
            fi
        done
    else
        echo "Non pull request"
fi

if [ -s "$FAILED_PACKAGES" ] ; then
    sed -e 's/^/- /' -e "iFailed packages:" "$FAILED_PACKAGES" 1>&2
    exit 1
fi
