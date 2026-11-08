#!/usr/bin/env bash
# Repositórios de terceiros. Chrome e Brave já vêm em /etc/yum.repos.d (system_files);
# o rpm-ostree busca as chaves GPG pelas URLs "gpgkey=" dos arquivos .repo.
set -euo pipefail

FEDORA="$(rpm -E %fedora)"
need=()
rpm -q rpmfusion-free-release >/dev/null 2>&1 \
    || need+=("https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${FEDORA}.noarch.rpm")
rpm -q rpmfusion-nonfree-release >/dev/null 2>&1 \
    || need+=("https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDORA}.noarch.rpm")

if [ "${#need[@]}" -gt 0 ]; then
    rpm-ostree install "${need[@]}"
fi
rpm-ostree cleanup -m
