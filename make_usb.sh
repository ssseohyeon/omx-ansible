#!/bin/bash
# USB 배포 번들 만들기 — 받는 사람은 USB의 omx-ansible/README.md 1-α 순서대로 하면 됨
# 사용: ./make_usb.sh /media/$USER/<USB라벨>
set -e
DEST="${1:?사용법: ./make_usb.sh /media/\$USER/<USB라벨>}"
SRC="$(cd "$(dirname "$0")" && pwd)"

echo "[1/2] omx-ansible 복사 (.venv·.git 제외)..."
rsync -a --delete --exclude .venv --exclude .git "$SRC/" "$DEST/omx-ansible/"

OM="$HOME/open_manipulator"
if [ -d "$OM" ]; then
  echo "[2/2] open_manipulator 원본 복사 (~124MB)..."
  rsync -a --delete "$OM/" "$DEST/open_manipulator/"
else
  echo "[2/2] ~/open_manipulator 없음 — 받는 쪽에서 prepare_source.yml 로 재조립하면 됨 (인터넷 필요)"
fi

sync
echo "완료: $DEST (안전 제거 후 뽑을 것)"
