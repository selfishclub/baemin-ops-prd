#!/bin/bash
# baemin-ops-prd 상태 판별
# 사용: detect.sh [찾기 시작할 폴더]   (기본: 현재 폴더)
# 출력:
#   CAMP <제출 폴더 경로>  또는  NO_CAMP
#   (CAMP면) 사장님 폴더마다: 폴더 | PRD_전체 | v1 PRD | v2 PRD | 사용메모 기록 줄 | 중간점검
#   (NO_CAMP면) 지금 폴더의 같은 파일 상태 (있을 때만)

start="$(cd "${1:-$PWD}" 2>/dev/null && pwd)" || { echo "폴더 없음: $1"; exit 1; }
skill_dir="$(cd "$(dirname "$0")/.." && pwd)"

# 양식에 없는 줄 수 → 빈양식 / 일부 / 작성됨
state() {
  local file="$1" tpl="$2"
  [ -f "$file" ] || { echo "없음"; return; }
  [ -f "$tpl" ] || tpl="$skill_dir/templates/$(basename "$tpl")"
  local n
  n=$(grep -vxF -f "$tpl" "$file" 2>/dev/null | grep -cv '^[[:space:]]*$')
  if [ "$n" -le 6 ]; then echo "빈양식"; elif [ "$n" -le 15 ]; then echo "일부"; else echo "작성됨"; fi
}

# 사용메모: 예시 줄(9/17 시연) 말고 날짜로 시작하는 표 줄 수
memo_rows() {
  local file="$1"
  [ -f "$file" ] || { echo "-"; return; }
  local rows notes
  rows=$(grep -E '^\| *[0-9]{1,2}/[0-9]{1,2} *\|' "$file" | grep -v '시연용 가짜 데이터로 처음 끝까지' | grep -cvE '^\| *[0-9/]+ *\| *\| *\|')
  # 「떠오른 것」·「반응」 아래 글머리 기호 중 내용이 있는 줄
  notes=$(grep -E '^- +[^[:space:]]' "$file" | grep -cv '^- *$')
  echo "기록 ${rows}·메모 ${notes}"
}

# 캠프 제출 폴더 찾기: 현재 위치에서 위로, 그다음 아래로
camp=""
dir="$start"
while [ "$dir" != "/" ]; do
  c=$(find "$dir" -maxdepth 1 -type d -name '02_실전캠프*실습제출' 2>/dev/null | head -1)
  [ -n "$c" ] && { camp="$c"; break; }
  case "$(basename "$dir")" in 02_실전캠프*실습제출) camp="$dir"; break;; esac
  dir="$(dirname "$dir")"
done
[ -z "$camp" ] && camp=$(find "$start" -maxdepth 3 -type d -name '02_실전캠프*실습제출' 2>/dev/null | head -1)

if [ -n "$camp" ]; then
  echo "CAMP $camp"
  # 시작 위치가 사장님 폴더 안이면 그 폴더를 알려 준다
  case "$start/" in "$camp"/*조_*/*) mine="${start#"$camp"/}"; echo "MINE ${mine%%/*}";; esac
  tpl="$camp/_양식"
  printf '%s\n' "폴더 | PRD_전체 | v1 PRD | v2 PRD | 사용메모 기록 | 중간점검"
  for d in "$camp"/*조_*/; do
    [ -d "$d" ] || continue
    chk=$(ls "$d"중간점검*.md 2>/dev/null | head -1)
    printf '%s | %s | %s | %s | %s | %s\n' \
      "$(basename "$d")" \
      "$(state "$d/PRD_전체.md" "$tpl/PRD_전체.md")" \
      "$(state "$d/v1/PRD.md" "$tpl/PRD.md")" \
      "$(state "$d/v2/PRD.md" "$tpl/PRD.md")" \
      "$(memo_rows "$d/v1/사용메모.md")" \
      "$( [ -n "$chk" ] && state "$chk" "$tpl/$(basename "$chk")" || echo 없음)"
  done
else
  echo "NO_CAMP"
  t="$skill_dir/templates"
  if [ -f "$start/PRD_전체.md" ] || [ -f "$start/v1/PRD.md" ]; then
    printf '%s\n' "PRD_전체 | v1 PRD | v2 PRD | 사용메모 기록 | 중간점검"
    printf '%s | %s | %s | %s | %s\n' \
      "$(state "$start/PRD_전체.md" "$t/PRD_전체.md")" \
      "$(state "$start/v1/PRD.md" "$t/PRD.md")" \
      "$(state "$start/v2/PRD.md" "$t/PRD.md")" \
      "$(memo_rows "$start/v1/사용메모.md")" \
      "$(state "$start/중간점검.md" "$t/중간점검.md")"
  else
    echo "기획 파일 없음 (새로 시작)"
  fi
fi
