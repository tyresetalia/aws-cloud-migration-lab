#!/usr/bin/env python3
"""
Automated Database Cutover & Data Migration Script
Transfers schema & data from local on-prem baseline into Amazon RDS MySQL.
"""

import os
import subprocess
import time

RDS_HOST = "migration-mysql-db.cba62y4wg81m.eu-west-1.rds.amazonaws.com"
RDS_USER = "admin"
RDS_PASS = "Migration2026Secure!"
DB_NAME = "onprem_store"
INSTANCE_ID = "i-08202ae0f9793cfe2"

def execute_remote_cutover():
    print("=" * 65)
    print(" [DATABASE CUTOVER] Migrating On-Prem Data to Amazon RDS MySQL")
    print("=" * 65)
    print(f"[+] Target RDS Host : {RDS_HOST}")
    print(f"[+] Database Name   : {DB_NAME}")
    print(f"[+] Migration Bridge: EC2 ({INSTANCE_ID})")
    
    # Read the local sql file
    sql_path = os.path.join("source-environment", "db", "schema_and_data.sql")
    with open(sql_path, "r", encoding="utf-8") as f:
        sql_content = f.read()

    # Base64 encode to safely pass via SSM or shell
    import base64
    b64_sql = base64.b64encode(sql_content.encode("utf-8")).decode("utf-8")

    commands = [
        f"echo '{b64_sql}' | base64 -d > /tmp/schema_and_data.sql",
        f"mysql -h {RDS_HOST} -u {RDS_USER} -p'{RDS_PASS}' {DB_NAME} < /tmp/schema_and_data.sql",
        f"mysql -h {RDS_HOST} -u {RDS_USER} -p'{RDS_PASS}' {DB_NAME} -e 'SHOW TABLES; SELECT COUNT(*) AS customer_count FROM customers; SELECT COUNT(*) AS product_count FROM products; SELECT COUNT(*) AS order_count FROM orders;'"
    ]
    
    print("\n[+] Triggering cutover on RDS via web server bridge...")
    cmd_str = "; ".join(commands)
    
    # Try AWS SSM Run Command or direct bridge
    send_cmd = [
        "aws", "ssm", "send-command",
        "--instance-ids", INSTANCE_ID,
        "--document-name", "AWS-RunShellScript",
        "--parameters", f"commands=[\"{cmd_str}\"]",
        "--output", "json"
    ]
    
    res = subprocess.run(send_cmd, capture_output=True, text=True)
    if res.returncode == 0:
        print("[+] SSM Command dispatched successfully.")
        import json
        cmd_id = json.loads(res.stdout)["Command"]["CommandId"]
        print(f"    Command ID: {cmd_id}")
        print("[+] Waiting for cutover execution to complete...")
        time.sleep(10)
        # Check command output
        get_out = [
            "aws", "ssm", "get-command-invocation",
            "--command-id", cmd_id,
            "--instance-id", INSTANCE_ID,
            "--output", "json"
        ]
        out_res = subprocess.run(get_out, capture_output=True, text=True)
        print("\n=== Cutover Output ===")
        print(out_res.stdout)
    else:
        print("[!] Note on SSM: Instance may still be initializing or SSM agent policy needed.")
        print(res.stderr)

if __name__ == "__main__":
    execute_remote_cutover()
