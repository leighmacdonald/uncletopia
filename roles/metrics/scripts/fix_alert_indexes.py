#!/usr/bin/env python3
"""Drop stale uniqueness indexes from a Grafana DB created by a newer version.

Grafana 10.4 leaves these guid columns empty, so a DB that still has the newer
unique indexes can only hold one provisioned alert rule. Removing them is safe:
10.4 does not use the columns and does not recreate the indexes.

Prints "changed" only when an index was actually dropped, so Ansible stays
idempotent.
"""

import os
import sqlite3
import sys

STALE_INDEXES = (
    "UQE_alert_rule_guid",
    "UQE_alert_rule_version_rule_guid_version",
    "UQE_alert_rule_version_rule_org_id_rule_uid_rule_guid_version",
)


def main():
    db_path = sys.argv[1]
    if not os.path.exists(db_path):
        print("unchanged")
        return

    conn = sqlite3.connect(db_path, timeout=30)
    try:
        present = set()
        for table in ("alert_rule", "alert_rule_version"):
            present.update(
                row[1] for row in conn.execute(f"PRAGMA index_list({table})")
            )
        dropped = [name for name in STALE_INDEXES if name in present]
        for name in dropped:
            conn.execute(f"DROP INDEX IF EXISTS {name}")
        conn.commit()
    finally:
        conn.close()

    print("changed" if dropped else "unchanged")


if __name__ == "__main__":
    main()
