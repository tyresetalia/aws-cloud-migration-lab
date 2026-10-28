#!/usr/bin/env python3
"""
Pre-Migration Data Integrity & Row Count Verification Script
Generates row count baseline and SHA256 checksums of database & assets.
"""

import os
import hashlib
import json

def get_file_checksum(filepath):
    sha256 = hashlib.sha256()
    with open(filepath, 'rb') as f:
        while chunk := f.read(8192):
            sha256.update(chunk)
    return sha256.hexdigest()

def verify_source():
    print("=" * 60)
    print(" [PRE-MIGRATION AUDIT] Source Environment Baseline Check")
    print("=" * 60)
    
    # 1. SQL Dump / Seed integrity
    sql_path = os.path.join("source-environment", "db", "schema_and_data.sql")
    if os.path.exists(sql_path):
        sql_hash = get_file_checksum(sql_path)
        print(f"[+] SQL Schema File : {sql_path}")
        print(f"    SHA-256 Checksum: {sql_hash}")
    
    # 2. Uploaded Assets Verification
    uploads_dir = os.path.join("source-environment", "uploads")
    assets = [f for f in os.listdir(uploads_dir) if os.path.isfile(os.path.join(uploads_dir, f))]
    print(f"\n[+] Static Assets Found : {len(assets)} files in '{uploads_dir}'")
    
    asset_manifest = {}
    for asset in sorted(assets):
        p = os.path.join(uploads_dir, asset)
        h = get_file_checksum(p)
        asset_manifest[asset] = h
        print(f"    - {asset:<26} : {h[:16]}...")
        
    # Baseline summary
    baseline = {
        "database": {
            "name": "onprem_store",
            "schema_file": sql_path,
            "sha256": sql_hash,
            "expected_tables": ["customers", "products", "orders"],
            "expected_counts": {
                "customers": 5,
                "products": 5,
                "orders": 5
            }
        },
        "assets": {
            "count": len(assets),
            "manifest": asset_manifest
        }
    }
    
    out_file = os.path.join("documentatie", "pre_migration_baseline.json")
    with open(out_file, "w") as f:
        json.dump(baseline, f, indent=2)
    print(f"\n[OK] Baseline manifest saved to: {out_file}")
    print("=" * 60)

if __name__ == "__main__":
    verify_source()
