#!/bin/sh
# Stands in for kamal, aws and gh in the eval sandbox: logs the call for the grader, then
# refuses it. The log sits next to the stub itself, found through links (bin/kamal in the
# clone is one), so a call is logged even from an emptied environment (env -i).
log="$(dirname "$(readlink -f "$0")")/calls.log"
echo "$(basename "$0") $*" >> "$log"
echo "refused: $(basename "$0") is a stub in the eval sandbox" >&2
exit 1
